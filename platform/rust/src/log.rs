//! The list of things to be displayed on screen.
//!
//! An item is a record that can generate content for rendering.
//!
//! A `Log` owns its items outright and holds no reference back to whatever
//! produced them. Producers keep the `LogId` of anything they published and
//! send a whole replacement item when it changes.

use std::{
    collections::VecDeque,
    sync::atomic::{AtomicU64, Ordering},
    time::{SystemTime, UNIX_EPOCH},
};

use crate::kiss::Ax25Addr;

const MAX_LOG_ITEMS: usize = 20000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LogId(u64);

static NEXT_LOG_ID: AtomicU64 = AtomicU64::new(1);

pub fn next_log_id() -> LogId {
    LogId(NEXT_LOG_ID.fetch_add(1, Ordering::Relaxed))
}

pub fn utc_timestamp(at: SystemTime) -> String {
    let secs = at
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("[{:02}:{:02}:{:02}Z]", (secs / 3600) % 24, (secs / 60) % 60, secs % 60)
}

pub fn format_digipeaters(digipeaters: &[Ax25Addr]) -> String {
    let last_repeated = digipeaters.iter().rposition(|d| d.repeated());
    digipeaters
        .iter()
        .enumerate()
        .map(|(i, d)| if Some(i) == last_repeated { format!("{d}*") } else { d.to_string() })
        .collect::<Vec<String>>()
        .join(",")
}

/// A flattened APRS packet for display.
#[derive(Debug, Clone)]
pub struct FrameLogItem {
    pub seq: u64,
    pub at: SystemTime,
    pub source: String,
    pub dest: String,
    pub addressee: Option<String>,
    pub msg_id: Option<String>,
    pub data_type_id: char,
    pub body: String,
    pub digipeaters: String,
    pub ackable: bool,
    pub acked: bool,
    pub repeats: usize,
}

impl FrameLogItem {
    pub fn header(&self) -> String {
        let mut header = format!(
            "{:04}: {} {} ({})",
            self.seq,
            utc_timestamp(self.at),
            self.source,
            self.dest,
        );

        if let Some(addressee) = &self.addressee {
            header.push_str(&format!(" → {}", addressee));
            if let Some(id) = &self.msg_id {
                header.push_str(&format!(" {{{id}"));
            }
        }

        let mut markers: Vec<String> = Vec::new();

        if self.ackable {
            markers.push(format!("ack:{}", if self.acked { "✓" } else { "_" }));
        }

        if self.repeats > 0 {
            markers.push(format!("rpt:{}", self.repeats));
        }

        if !markers.is_empty() {
            header.push_str("  ");
            header.push_str(&markers.join(" "));
        }

        header
    }

    fn line_count(&self) -> usize {
        if self.digipeaters.is_empty() { 3 } else { 4 }
    }

    fn lines(&self) -> Vec<String> {
        let mut lines = vec![self.header()];
        if !self.digipeaters.is_empty() {
            lines.push(format!("via {}", self.digipeaters));
        }
        lines.push(format!("{} {}", self.data_type_id, self.body));
        lines.push(String::new());
        lines
    }
}

/// General purpose text, e.g. help/usage, a frame dump, an error.
#[derive(Debug, Clone)]
pub struct Notice {
    pub lines: Vec<String>,
}

#[derive(Debug, Clone)]
pub enum LogItem {
    Frame { id: LogId, item: FrameLogItem },
    Notice { id: LogId, notice: Notice },
}

impl LogItem {
    pub fn frame(id: LogId, item: FrameLogItem) -> Self {
        Self::Frame { id, item }
    }

    pub fn notice(lines: Vec<String>) -> Self {
        Self::Notice { id: next_log_id(), notice: Notice { lines } }
    }

    pub fn id(&self) -> LogId {
        match self {
            Self::Frame { id, .. } => *id,
            Self::Notice { id, .. } => *id,
        }
    }

    pub fn line_count(&self) -> usize {
        match self {
            Self::Frame { item, .. } => item.line_count(),
            Self::Notice { notice, .. } => notice.lines.len(),
        }
    }

    pub fn lines(&self) -> Vec<String> {
        match self {
            Self::Frame { item, .. } => item.lines(),
            Self::Notice { notice, .. } => notice.lines.clone(),
        }
    }
}

/// The items on screen, oldest first.
#[derive(Debug)]
pub struct Log {
    items: VecDeque<LogItem>,
    max_items: usize,
}

impl Log {
    pub fn new() -> Self {
        Self {
            items: VecDeque::with_capacity(MAX_LOG_ITEMS),
            max_items: MAX_LOG_ITEMS,
        }
    }

    pub fn push(&mut self, item: LogItem) {
        if self.items.len() == self.max_items {
            self.items.pop_front();
        }
        self.items.push_back(item);
    }

    /// Replaces an item with a newer version of itself, matched on `LogId`.
    ///
    /// If an item is not found, the replace is ignored.
    pub fn replace(&mut self, replacement: LogItem) {
        let id = replacement.id();
        if let Some(existing) = self.items.iter_mut().rev().find(|i| i.id() == id) {
            *existing = replacement;
        }
    }

    pub fn clear(&mut self) {
        self.items.clear();
    }

    pub fn iter(&self) -> impl DoubleEndedIterator<Item = &LogItem> {
        self.items.iter()
    }

    pub fn total_lines(&self) -> usize {
        self.items.iter().map(|i| i.line_count()).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frame_log_item(seq: u64) -> FrameLogItem {
        FrameLogItem {
            seq,
            at: UNIX_EPOCH,
            source: String::from("NOCALL"),
            dest: String::from("APKTY1"),
            addressee: None,
            msg_id: None,
            data_type_id: ':',
            body: String::from("hello"),
            digipeaters: String::new(),
            ackable: false,
            acked: false,
            repeats: 0,
        }
    }

    #[test]
    fn replace_replaces_the_item_with_the_matching_id() {
        let mut log = Log::new();
        let id = next_log_id();

        log.push(LogItem::frame(id, frame_log_item(1)));
        log.push(LogItem::notice(vec![String::from("unrelated")]));

        let mut changed = frame_log_item(1);
        changed.repeats = 2;
        log.replace(LogItem::frame(id, changed));

        let replaced = log.iter().find(|i| i.id() == id).expect("item should still be present");
        assert!(replaced.lines()[0].contains("rpt:2"), "got {:?}", replaced.lines()[0]);
    }

    #[test]
    fn replace_for_an_evicted_item_is_dropped() {
        let mut log = Log::new();
        log.replace(LogItem::frame(next_log_id(), frame_log_item(1)));

        assert_eq!(log.total_lines(), 0);
    }

    #[test]
    fn push_at_capacity_evicts_the_oldest_item() {
        let mut log = Log::new();
        log.max_items = 2;

        let first = next_log_id();
        log.push(LogItem::frame(first, frame_log_item(1)));
        log.push(LogItem::frame(next_log_id(), frame_log_item(2)));
        log.push(LogItem::frame(next_log_id(), frame_log_item(3)));

        assert!(log.iter().all(|i| i.id() != first));
    }

    #[test]
    fn total_lines_counts_the_via_line_only_when_there_is_a_path() {
        let mut log = Log::new();
        log.push(LogItem::frame(next_log_id(), frame_log_item(1)));
        assert_eq!(log.total_lines(), 3);

        let mut digipeated = frame_log_item(2);
        digipeated.digipeaters = String::from("WIDE1-1*");
        log.push(LogItem::frame(next_log_id(), digipeated));
        assert_eq!(log.total_lines(), 7);
    }

    #[test]
    fn header_shows_addressee_and_message_id() {
        let mut item = frame_log_item(3);
        item.addressee = Some(String::from("NOCALL-1"));
        item.msg_id = Some(String::from("5"));

        let header = item.header();

        assert!(header.starts_with("0003: "), "got {header}");
        assert!(header.contains("NOCALL (APKTY1)"), "got {header}");
        assert!(header.contains("→ NOCALL-1 {5"), "got {header}");
    }

    #[test]
    fn header_shows_ack_marker_and_repeat_count() {
        let mut item = frame_log_item(0);
        item.ackable = true;
        item.acked = true;
        item.repeats = 2;

        assert!(item.header().ends_with("  ack:✓ rpt:2"), "got {}", item.header());
    }

    #[test]
    fn header_unacked_ackable_message_shows_pending_marker() {
        let mut item = frame_log_item(0);
        item.ackable = true;

        let header = item.header();

        assert!(header.contains("ack:_"), "got {header}");
        assert!(!header.contains("rpt:"), "got {header}");
    }

    #[test]
    fn header_omits_ack_marker_when_not_ackable() {
        assert!(!frame_log_item(0).header().contains("ack:"));
    }

    #[test]
    fn header_omits_addressee_when_there_is_none() {
        assert!(!frame_log_item(0).header().contains("→"));
    }
}
