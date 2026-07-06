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

//pub struct KissFrame {
//
//}

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
        while running.load(Ordering::Relaxed) {
            let mut buf = [0; 128];
            match stream.read(&mut buf) {
                Ok(0) => break,
                Ok(num_read) => {
                    tracing::info!(num_read, "read bytes");
                },
                Err(e) => match e.kind() {
                    ErrorKind::Interrupted | 
                    ErrorKind::TimedOut |ErrorKind::WouldBlock => {
                        tracing::info!("blocking");
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

//    pub fn next(&self) -> Result<Event> {
//        Ok(self.receiver.recv()?)
//    }
}
