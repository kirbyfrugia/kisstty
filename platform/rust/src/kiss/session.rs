use std::{
    collections::{ HashMap, VecDeque },
    sync::mpsc,
    time::{ SystemTime, UNIX_EPOCH },
};

use crate::{
    config::Config,
    kiss::{parse_digipeater_path, AprsData, AprsMessage, Ax25Addr, Ax25Frame, KissClient},
    message::Message,
    ui::OutputUpdate,
};

const MAX_MESSAGES: usize = 10000;

#[derive(Debug)]
pub struct KissSession {
    message_sender: mpsc::Sender<Message>,
    client: Option<KissClient>,
    source: Option<Ax25Addr>,
    digipeaters: Vec<Ax25Addr>,
    outgoing_ids: HashMap<String, u64>,
    messages: VecDeque<String>,
}

fn to_base36(mut value: u64) -> String {
    const DIGITS: &[u8] = b"0123456789abcdefghijklmnopqrstuvwxyz";
    if value == 0 {
        return String::from("0");
    }

    let mut buf = Vec::new();
    while value > 0 {
        buf.push(DIGITS[(value % 36) as usize]);
        value /= 36;
    }
    buf.reverse();
    String::from_utf8(buf).expect("base36 digits are ascii")
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
            digipeaters: Vec::new(),
            outgoing_ids: HashMap::new(),
            messages: VecDeque::with_capacity(MAX_MESSAGES),
        }
    }

    pub fn start(&mut self, config: &Config) {
        if self.client.is_some() {
            return;
        }
        self.source = match Ax25Addr::parse(&config.callsign) {
            Ok(addr) => Some(addr),
            Err(err) => {
                tracing::warn!(%err, "ignoring invalid source callsign from config");
                None
            }
        };
        self.digipeaters = parse_digipeater_path(&config.digipeaters).unwrap_or_else(|err| {
            tracing::warn!(%err, "ignoring invalid digipeater path from config");
            Vec::new()
        });
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
                self.display_frame(&frame);
                None
            },
            other => Some(other),
        }
    }

    fn send_aprs_message(&mut self, addressee: String, text: String) {
        let Some(source) = self.source.clone() else {
            tracing::warn!("no source callsign; dropping outgoing message");
            return;
        };

        let id = if addressee == AprsMessage::BROADCAST_ADDRESSEE {
            None
        } else {
            Some(self.next_message_id(&addressee))
        };

        let dest = Ax25Addr::new(Ax25Addr::AX25DEST.to_string(), 0);
        let data = AprsData::Message(AprsMessage::new(addressee, text, id));
        let frame = Ax25Frame::new(dest, source, self.digipeaters.clone(), data);

        // echo the outgoing frame to our own output, then transmit it
        self.display_frame(&frame);
        self.send_frame(&frame);
    }

    fn next_message_id(&mut self, addressee: &str) -> String {
        let next = self.outgoing_ids.entry(addressee.to_string()).or_insert(1);
        let id = to_base36(*next);
        *next += 1;
        id
    }

    fn send_frame(&self, frame: &Ax25Frame) {
        match &self.client {
            Some(client) => client.send(frame.encode()),
            None => tracing::warn!("no kiss connection; dropping outgoing frame"),
        }
    }

    fn display_frame(&self, ax25_frame: &Ax25Frame) {
        let mut lines: Vec<String> = Vec::new();

        let mut header = format!("{} {}", utc_timestamp(), ax25_frame.header());
        if let Some(id) = ax25_frame.message_id() {
            header.push_str(&format!(" {{{id}"));
        }
        lines.push(header);

        let digipeaters = ax25_frame.digipeaters();
        if digipeaters.len() > 0 {
            lines.push(format!("via {}", &digipeaters));
        }
        lines.push(format!("{} {}", ax25_frame.data_type_id(), ax25_frame.body()));
        lines.push(String::from(""));

        let output_update = OutputUpdate::new(lines);
        let _ = self.message_sender.send(Message::Output(output_update));
    }

}
