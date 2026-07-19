use std::{
    collections::{ HashMap, VecDeque },
    sync::mpsc,
    time::{ Duration, Instant, SystemTime, UNIX_EPOCH },
};

use crate::{
    config::Config,
    kiss::{parse_digipeater_path, AprsData, AprsMessage, Ax25Addr, Ax25Frame, KissClient},
    message::Message,
    ui::UiId,
    ui::UiLine,
    ui::OutputUpdate,
};

const MAX_FRAMES: usize = 10000;

const ACK_THROTTLE: Duration = Duration::from_secs(30);

#[derive(Debug)]
struct SessionFrame {
    ui_id: UiId,
    frame: Ax25Frame,
    acks: Vec<Ax25Frame>,
}

impl SessionFrame {
    pub fn new(ui_id: UiId, frame: Ax25Frame) -> Self {
        Self {
            ui_id,
            frame,
            acks: Vec::new(),
        }
    }
}

#[derive(Debug)]
pub struct KissSession {
    message_sender: mpsc::Sender<Message>,
    client: Option<KissClient>,
    source: Option<Ax25Addr>,
    digipeaters: Vec<Ax25Addr>,
    outgoing_ids: HashMap<String, u64>,
    last_acked: HashMap<(String, String), Instant>,
    frames: VecDeque<SessionFrame>,
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
            last_acked: HashMap::new(),
            frames: VecDeque::with_capacity(MAX_FRAMES),
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
                let id = if addressee == AprsMessage::BROADCAST_ADDRESSEE {
                    None
                } else {
                    Some(self.next_message_id(&addressee))
                };
                if let Some(frame) = self.send_aprs_message(AprsMessage::new(addressee, text, id)) {
                    let ui_id = self.display_frame(&frame);
                    let session_frame = SessionFrame::new(ui_id, frame);
                    self.frames.push_back(session_frame);
                }
                None
            },
            Message::Ax25FrameReceived(frame) => {
                self.handle_received_frame(frame);
                None
            },
            other => Some(other),
        }
    }

    fn send_aprs_message(&mut self, message: AprsMessage) -> Option<Ax25Frame> {
        let Some(source) = self.source.clone() else { return None; };

        let dest = Ax25Addr::new(Ax25Addr::AX25DEST.to_string(), 0);
        let data = AprsData::Message(message);
        let frame = Ax25Frame::new(dest, source, self.digipeaters.clone(), data);
        self.send_frame(&frame);
        Some(frame)
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

    fn handle_received_frame(&mut self, frame: Ax25Frame) {
        let ui_id = self.display_frame(&frame);
        self.maybe_send_ack(&frame);
        let session_frame = SessionFrame::new(ui_id, frame);
        self.frames.push_back(session_frame);
    }

    fn maybe_send_ack(&mut self, rcvd_frame: &Ax25Frame) {
        let Some(me) = self.source.clone() else { return };
        let Some((ack_addressee, msg_id)) = rcvd_frame.ack_target(&me) else { return };

        let now = Instant::now();
        self.last_acked.retain(|_, &mut t| now.duration_since(t) < ACK_THROTTLE);

        let key = (ack_addressee.to_string(), msg_id.to_string());
        if self.last_acked.contains_key(&key) { return; }

        tracing::debug!(to = %key.0, id = %key.1, "acking received message");
        self.send_aprs_message(AprsMessage::new(key.0.clone(), format!("ack{}", key.1), None));
        self.last_acked.insert(key, now);
    }

    fn display_frame(&self, ax25_frame: &Ax25Frame) -> UiId {
        let mut ui_lines: Vec<UiLine> = Vec::new();

        let mut header = format!("{} {}", utc_timestamp(), ax25_frame.header());
        if let Some(id) = ax25_frame.message_id() {
            header.push_str(&format!(" {{{id}"));
        }
        ui_lines.push(UiLine::new(header));

        let digipeaters = ax25_frame.digipeaters();
        if digipeaters.len() > 0 {
            ui_lines.push(UiLine::new(format!("via {}", &digipeaters)));
        }
        ui_lines.push(UiLine::new(format!("{} {}", ax25_frame.data_type_id(), ax25_frame.body())));
        ui_lines.push(UiLine::new(String::from("")));

        let output_update = OutputUpdate::new(ui_lines);
        let ui_id = output_update.ui_id.clone();
        let _ = self.message_sender.send(Message::Output(output_update));
        ui_id
    }

}
