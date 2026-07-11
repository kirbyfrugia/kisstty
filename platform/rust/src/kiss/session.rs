use std::{
    collections::VecDeque,
    sync::mpsc,
    time::{ SystemTime, UNIX_EPOCH },
};

use crate::{
    config::Config,
    kiss::{AprsData, AprsMessage, Ax25Addr, Ax25Frame, KissClient},
    message::Message,
    ui::OutputUpdate,
};

const MAX_MESSAGES: usize = 10000;

#[derive(Debug)]
pub struct KissSession {
    message_sender: mpsc::Sender<Message>,
    client: Option<KissClient>,
    source: Option<Ax25Addr>,
    messages: VecDeque<String>,
}

fn utc_timestamp() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("[{:02}:{:02}:{:02}Z]", (secs / 3600) % 24, (secs / 60) % 60, secs % 60)
}

impl KissSession {
    pub fn new(message_sender: mpsc::Sender<Message>) -> Self {
        Self {
            message_sender: message_sender,
            client: None,
            source: None,
            messages: VecDeque::with_capacity(MAX_MESSAGES),
        }
    }

    pub fn start(&mut self, config: &Config) {
        if self.client.is_some() {
            return;
        }
        self.source = Some(Ax25Addr::new(config.callsign.clone(), 0));
        self.client = Some(KissClient::new(
            config.kiss_host.clone(),
            config.kiss_port,
            self.message_sender.clone(),
        ));
    }

    pub fn restart(&mut self, config: &Config) {
        self.client = None;
        self.start(config);
    }

    pub fn try_claim(&mut self, message: Message) -> Option<Message> {
        match message {
            Message::SendAprsMessage { addressee, text } => {
                self.send_aprs_message(addressee, text);
                None
            },
            Message::Ax25FrameReceived(frame) => {
                self.frame_received(frame);
                None
            },
            other => Some(other),
        }
    }

    fn send_aprs_message(&self, addressee: String, text: String) {
        let Some(source) = &self.source else {
            tracing::warn!("no source callsign; dropping outgoing message");
            return;
        };

        let dest = Ax25Addr::new(Ax25Addr::AX25DEST.to_string(), 0);
        let data = AprsData::Message(AprsMessage::new(addressee, text));
        let frame = Ax25Frame::new(dest, source.clone(), Vec::new(), data);

        // echo the outgoing frame to our own output, then transmit it
        self.frame_received(frame.clone());
        self.send_frame(frame);
    }

    fn send_frame(&self, frame: Ax25Frame) {
        match &self.client {
            Some(client) => client.send(frame),
            None => tracing::warn!("no kiss connection; dropping outgoing frame"),
        }
    }

    fn frame_received(&self, ax25_frame: Ax25Frame) {
        let mut lines: Vec<String> = Vec::new();

        lines.push(format!("{} {}", utc_timestamp(), ax25_frame.header()));

        let digipeaters = ax25_frame.digipeaters();
        if digipeaters.len() > 0 {
            lines.push(format!("via {}", &digipeaters));
        }
        lines.push(format!(": {}", ax25_frame.body()));
        lines.push(String::from(""));

        let output_update = OutputUpdate::new(lines);
        let _ = self.message_sender.send(Message::Output(output_update));
    }

}
