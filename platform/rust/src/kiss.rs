use std::{
    io::{ErrorKind, Read},
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc, Arc,
    },
    net::{TcpStream, ToSocketAddrs},
    thread,
    time::Duration,
};

//use color_eyre::Result;

use crate::{
    config,
    message::Message,
};

#[derive(Debug)]
pub struct KissAddr {
    addr: String,
    ssid: u8,
    last_addr: bool,
}

impl KissAddr {
    fn process_addr(buf: &[u8; 7]) -> String {
        let mut addr = String::new();
        for &byte in &buf[0..6] {
            let shifted = byte >> 1;
            let byte_char = shifted as char;
            addr.push(byte_char);
        }

        return String::from(addr.trim_end());
    }

    pub fn new(buf: &[u8; 7]) -> Self {
        let addr = Self::process_addr(buf);
        let ssid = (buf[6] >> 1) & 0b0000_1111;

        // this is the last address in the header if
        // the lsb on byte 6 is 0.
        let last_byte = buf[6];
        let last_addr = last_byte & 0b0000_0001 != 0;

        Self {
            addr,
            ssid,
            last_addr
        }
    }
}

impl std::fmt::Display for KissAddr {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.ssid != 0 {
            write!(f, "{}-{}", self.addr, self.ssid)
        } else {
            write!(f, "{}", self.addr)
        }
    }
}

pub struct KissFrame {
    raw_bytes: Vec<u8>,
}

impl Default for KissFrame {
    fn default() -> Self {
        Self {
            raw_bytes: Vec::new(),
        }
    }
}

#[derive(Debug)]
pub struct Ax25Frame {
    dest: KissAddr,
    source: KissAddr,
    digipeaters: Vec<KissAddr>,
}

pub struct KissFrameState {
    waiting_on_first_fend: bool,
    in_fesc: bool,
    current_frame: KissFrame,
}

impl Default for KissFrameState {
    fn default() -> Self {
        Self {
            waiting_on_first_fend: true,
            in_fesc: false,
            current_frame: KissFrame::default(),
        }
    }
}

#[derive(Debug)]
pub struct KissClient {
    #[allow(dead_code)]
    sender: mpsc::Sender<Message>,
    #[allow(dead_code)]
    receiver: mpsc::Receiver<Message>,
    #[allow(dead_code)]
    handle: thread::JoinHandle<()>,
    running: Arc<AtomicBool>,
}

impl Drop for KissClient {
    fn drop(&mut self) {
        self.running.store(false, Ordering::Relaxed);
    }
}

impl KissClient {
    const KISS_FEND: u8 = 0xc0;
    const KISS_FESC: u8 = 0xdb;
    const KISS_TFEND: u8 = 0xdc;
    const KISS_TFESC: u8 = 0xdd;
    const KISS_CMD_TYPE_DATA: u8 = 0;

    pub fn new(host: String, port: u16, message_sender: mpsc::Sender<Message>) -> Self {
        let (sender, receiver) = mpsc::channel();
        let running = Arc::new(AtomicBool::new(true));

        let handle = {
            let running = running.clone();
            thread::spawn(move || Self::run(host, port, running, message_sender))
        };

        Self {
            sender,
            receiver,
            handle,
            running,
        }
    }

    fn run(host: String, port: u16, running: Arc<AtomicBool>, message_sender: mpsc::Sender<Message>) {
        if let Err(e) = config::validate_host(&host) {
            tracing::error!(host, port, "invalid kiss host: {}", e);
            return;
        }

        let connect_timeout = Duration::from_secs(5);
        let read_timeout = Duration::from_secs(5);

        while running.load(Ordering::Relaxed) {
            let stream = match Self::connect(&host, port, connect_timeout) {
                Some(stream) => stream,
                None => {
                    thread::sleep(connect_timeout);
                    continue
                },
            };

            if !running.load(Ordering::Relaxed) {
                break
            }

            tracing::info!(host, port, "connected to kiss server");
            let _ = stream.set_read_timeout(Some(read_timeout));

            Self::read_loop(stream, &running, &message_sender);
        }
    }

    fn connect(host: &str, port: u16, timeout: Duration) -> Option<TcpStream> {
        let addrs = match (host, port).to_socket_addrs() {
            Ok(addrs) => addrs,
            Err(e) => {
                tracing::warn!(kind = ?e.kind(), host, port, "error resolving kiss host");
                return None
            },
        };

        // A hostname can resolve to several addresses.
        // try each until one connects.
        for addr in addrs {
            match TcpStream::connect_timeout(&addr, timeout) {
                Ok(stream) => return Some(stream),
                Err(e) => {
                    tracing::warn!(kind = ?e.kind(), %addr, host, port, "error connecting to kiss server");
                },
            }
        }

        None
    }

    fn read_loop(mut stream: TcpStream, running: &AtomicBool, _message_sender: &mpsc::Sender<Message>) {
        let mut kiss_frame_state = KissFrameState::default();
        while running.load(Ordering::Relaxed) {
            let mut buf = [0; 128];
            match stream.read(&mut buf) {
                Ok(0) => break,
                Ok(num_read) => {
                    Self::process_bytes(&mut kiss_frame_state, &buf[..num_read]);
                    tracing::info!(num_read, "processed bytes");
                },
                Err(e) => match e.kind() {
                    ErrorKind::Interrupted | 
                    ErrorKind::TimedOut |
                    ErrorKind::WouldBlock => {
                        continue
                    },
                    _ => {
                        tracing::error!(kind = ?e.kind(), "error reading bytes from kiss server");
                        break
                    }
                },
            }
        }
    }

    fn process_frame(kiss_frame: &KissFrame) -> Option<Ax25Frame> {
        if kiss_frame.raw_bytes.is_empty() { return None }

        const MIN_KISS_FRAME_SIZE: usize = 17; // cmd type + source + dest + ctrl + pid
        if kiss_frame.raw_bytes.len() < MIN_KISS_FRAME_SIZE {
            tracing::warn!(len = kiss_frame.raw_bytes.len(), "discarding invalid kiss frame - too small");
            return None
        }

        let cmd_type = kiss_frame.raw_bytes[0];
        if cmd_type != Self::KISS_CMD_TYPE_DATA {
            tracing::debug!(cmd_type, "ignoring non-data kiss frame");
            return None
        }

        tracing::info!(raw = ?kiss_frame.raw_bytes, "raw bytes");

        const MAX_KISS_ADDRS: usize = 10;
        let mut addrs: Vec<KissAddr> = Vec::new();
        let mut offset = 1;
        while addrs.len() < MAX_KISS_ADDRS && offset + 7 <= kiss_frame.raw_bytes.len() {
            let addr = KissAddr::new(kiss_frame.raw_bytes[offset..offset + 7].try_into().unwrap());
            let last_addr = addr.last_addr;
            addrs.push(addr);
            if last_addr { break }
            offset += 7;
        }

        let mut addrs = addrs.into_iter();
        let (Some(dest), Some(source)) = (addrs.next(), addrs.next()) else {
            tracing::warn!("kiss frame missing dest or source address");
            return None
        };
        let digipeaters = addrs.collect();

        Some(Ax25Frame { dest, source, digipeaters })
    }

    fn process_byte(kiss_frame_state: &mut KissFrameState, byte: u8) {
        // discard any bytes until our first FEND
        if kiss_frame_state.waiting_on_first_fend && byte != Self::KISS_FEND { return; }

        if kiss_frame_state.in_fesc {
            kiss_frame_state.in_fesc = false;
            match byte {
                Self::KISS_TFESC => {
                    kiss_frame_state.current_frame.raw_bytes.push(Self::KISS_FESC);
                }
                Self::KISS_TFEND => {
                    kiss_frame_state.current_frame.raw_bytes.push(Self::KISS_FEND);
                }
                _ => { //ignore unexpected }
                }
            }
        } else {
            kiss_frame_state.current_frame.raw_bytes.push(byte);
        }
    }

    fn process_bytes(mut kiss_frame_state: &mut KissFrameState, buf: &[u8]) {
        for &byte in buf.iter() {
            match byte {
                Self::KISS_FEND => {
                    if kiss_frame_state.waiting_on_first_fend {
                        kiss_frame_state.waiting_on_first_fend = false;
                    }

                    if let Some(frame) = Self::process_frame(&kiss_frame_state.current_frame) {
                        tracing::info!(dest = %frame.dest, source = %frame.source, digipeaters = ?frame.digipeaters, "parsed frame");
                    }

                    kiss_frame_state.current_frame = KissFrame::default();
                },
                Self::KISS_FESC => {
                    kiss_frame_state.in_fesc = true;
                },
                _ => {
                    Self::process_byte(&mut kiss_frame_state, byte);
                }
            }
        }
    }

//    pub fn next(&self) -> Result<Event> {
//        Ok(self.receiver.recv()?)
//    }
}
