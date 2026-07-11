use std::{
    collections::VecDeque,
    sync::mpsc,
    time::{ SystemTime, UNIX_EPOCH },
};

use crate::{
    kiss::{Ax25Frame},
    message::Message,
    ui::OutputUpdate,
};

const MAX_MESSAGES: usize = 10000;

#[derive(Debug)]
pub struct KissSession {
    message_sender: mpsc::Sender<Message>,
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
            messages: VecDeque::with_capacity(MAX_MESSAGES),
        }
    }

    pub fn frame_received(&self, ax25_frame: Ax25Frame) {
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
