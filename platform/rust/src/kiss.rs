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
    event::Event,
};

#[derive(Debug)]
pub struct KissClient {
    #[allow(dead_code)]
    sender: mpsc::Sender<Event>,
    #[allow(dead_code)]
    receiver: mpsc::Receiver<Event>,
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
    pub fn new(host: String, port: u16, event_sender: mpsc::Sender<Event>) -> Self {
        let (sender, receiver) = mpsc::channel();
        let running = Arc::new(AtomicBool::new(true));

        let handle = {
            let _event_sender = event_sender.clone();
            let _sender = sender.clone();
            let running = running.clone();
            let connect_timeout = Duration::from_secs(5);
            let read_timeout = Duration::from_secs(5);
            thread::spawn(move || {
                if let Err(e) = config::validate_host(&host) {
                    tracing::error!(host, port, "invalid kiss host: {}", e);
                    return;
                }

                while running.load(Ordering::Relaxed) {
                    let addrs = match (host.as_str(), port).to_socket_addrs() {
                        Ok(addrs) => addrs,
                        Err(e) => {
                            tracing::warn!(kind = ?e.kind(), host, port, "error resolving kiss host");
                            thread::sleep(connect_timeout);
                            continue
                        },
                    };

                    // A hostname can resolve to several addresses.
                    // try each until one connects.
                    let mut stream = None;
                    for addr in addrs {
                        match TcpStream::connect_timeout(&addr, connect_timeout) {
                            Ok(s) => {
                                stream = Some(s);
                                break
                            },
                            Err(e) => {
                                tracing::warn!(kind = ?e.kind(), %addr, host, port, "error connecting to kiss server");
                            },
                        }
                    }

                    let mut stream = match stream {
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

                    while running.load(Ordering::Relaxed) {
                        let mut buf = [0; 128];
                        let _num_read = match stream.read(&mut buf) {
                            Ok(0) => {
                                break
                            }
                            Ok(num_read) => {
                                tracing::info!(num_read, "read bytes");
                                num_read
                            },
                            Err(e) => {
                                match e.kind() {
                                    ErrorKind::Interrupted | ErrorKind::TimedOut | ErrorKind::WouldBlock => {
                                        tracing::info!("blocking");
                                        continue
                                    },
                                    _ => {
                                        tracing::error!(kind = ?e.kind(), "error reading bytes from kiss server");
                                        break
                                    }
                                }
                            }
                        };
                    }

                }
            })
        };

        Self {
            sender,
            receiver,
            handle,
            running,
        }

    }

//    pub fn next(&self) -> Result<Event> {
//        Ok(self.receiver.recv()?)
//    }
}
