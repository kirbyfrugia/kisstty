mod aprs;
mod ax25;
mod client;
mod session;

pub use aprs::AprsData;
pub use aprs::AprsMessage;
pub use ax25::parse_digipeater_path;
pub use ax25::Ax25Addr;
pub use ax25::Ax25Frame;
pub use client::KissClient;
pub use session::KissSession;

use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KissId(u64);

static NEXT_KISS_ID: AtomicU64 = AtomicU64::new(1);

pub fn next_kiss_id() -> KissId {
    KissId(NEXT_KISS_ID.fetch_add(1, Ordering::Relaxed))
}

#[allow(non_camel_case_types)]
pub struct KISS;

impl KISS {
    pub const FEND: u8 = 0xc0;
    pub const FESC: u8 = 0xdb;
    pub const TFEND: u8 = 0xdc;
    pub const TFESC: u8 = 0xdd;
    pub const CMD_TYPE_DATA: u8 = 0;

    pub fn encode(payload: &[u8]) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(payload.len() + 3);
        bytes.push(Self::FEND);
        bytes.push(Self::CMD_TYPE_DATA);
        for &byte in payload {
            match byte {
                Self::FEND => bytes.extend([Self::FESC, Self::TFEND]),
                Self::FESC => bytes.extend([Self::FESC, Self::TFESC]),
                _ => bytes.push(byte),
            }
        }
        bytes.push(Self::FEND);
        bytes
    }
}
