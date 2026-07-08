#[derive(Debug,Clone)]
pub enum AprsData {
    #[allow(dead_code)]
    Message(AprsMessage),
    #[allow(dead_code)]
    Status(AprsStatus),
    Unknown,
}

#[derive(Debug,Clone)]
pub struct AprsMessage {
    #[allow(dead_code)]
    pub addressee: String,
    #[allow(dead_code)]
    pub text: String,
}

#[derive(Debug,Clone)]
pub struct AprsStatus {
    #[allow(dead_code)]
    pub text: String,
}

impl AprsData {
    pub fn encode(&self) -> Vec<u8> {
        match self {
            AprsData::Message(msg) => msg.encode(),
            AprsData::Status(status) => status.encode(),
            AprsData::Unknown => Vec::new(),
        }
    }

    pub fn decode(info: &[u8]) -> Self {
        let Some((&data_type_id, rest)) = info.split_first() else {
            return AprsData::Unknown;
        };

        match data_type_id {
            b':' => AprsData::Message(AprsMessage::decode(rest)),
            b'>' => AprsData::Status(AprsStatus::decode(rest)),
            _ => AprsData::Unknown,
        }
    }
}

impl AprsMessage {
    pub const BROADCAST_ADDRESSEE: &str = "BROADCAST";

    pub fn new(addressee: String, text: String) -> Self {
        Self {
            addressee,
            text,
        }
    }

    fn encode(&self) -> Vec<u8> {
        format!(":{:<9}:{}", self.addressee, self.text).into_bytes()
    }

    fn decode(info: &[u8]) -> Self {
        let addressee = info.get(0..9)
            .map(|a| String::from_utf8_lossy(a).trim_end().to_string())
            .unwrap_or_default();
        let text = info.get(10..)
            .map(|t| String::from_utf8_lossy(t).into_owned())
            .unwrap_or_default();

        Self { addressee, text }
    }
}

impl std::fmt::Display for AprsMessage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:<9}:{}", self.addressee, self.text)
    }
}

impl AprsStatus {
    fn encode(&self) -> Vec<u8> {
        format!(">{}", self.text).into_bytes()
    }

    fn decode(info: &[u8]) -> Self {
        Self {
            text: String::from_utf8_lossy(info).into_owned(),
        }
    }
}
