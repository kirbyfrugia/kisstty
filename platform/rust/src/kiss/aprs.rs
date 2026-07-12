#[derive(Debug,Clone)]
pub enum AprsData {
    #[allow(dead_code)]
    Message(AprsMessage),
    #[allow(dead_code)]
    Status(AprsStatus),
}

#[derive(Debug,Clone)]
pub struct AprsMessage {
    #[allow(dead_code)]
    pub addressee: String,
    #[allow(dead_code)]
    pub text: String,
    #[allow(dead_code)]
    pub id: Option<String>,
}

#[derive(Debug,Clone)]
pub struct AprsStatus {
    #[allow(dead_code)]
    pub text: String,
}

impl AprsData {
    pub fn data_type_id(&self) -> char {
        match self {
            AprsData::Message(_) => ':',
            AprsData::Status(_) => '>',
        }
    }

    pub fn encode(&self) -> Vec<u8> {
        match self {
            AprsData::Message(msg) => msg.encode(),
            AprsData::Status(status) => status.encode(),
        }
    }

    pub fn decode(info: &[u8]) -> Option<Self> {
        let Some((&data_type_id, rest)) = info.split_first() else {
            tracing::warn!("ax25 frame has empty info field");
            return None;
        };

        match data_type_id {
            b':' => Some(AprsData::Message(AprsMessage::decode(rest))),
            b'>' => Some(AprsData::Status(AprsStatus::decode(rest))),
            other => {
                tracing::info!(
                    data_type = %(other as char),
                    text = %String::from_utf8_lossy(rest),
                    "discarding frame with unsupported aprs data type",
                );
                None
            }
        }
    }
}

impl AprsMessage {
    pub const BROADCAST_ADDRESSEE: &str = "BROADCAST";

    pub fn new(addressee: String, text: String, id: Option<String>) -> Self {
        Self {
            addressee,
            text,
            id,
        }
    }

    fn encode(&self) -> Vec<u8> {
        let mut encoded = format!(":{:<9}:{}", self.addressee, self.text);
        if let Some(id) = &self.id {
            encoded.push('{');
            encoded.push_str(id);
        }
        encoded.into_bytes()
    }

    fn decode(info: &[u8]) -> Self {
        let addressee = info.get(0..9)
            .map(|a| String::from_utf8_lossy(a).trim_end().to_string())
            .unwrap_or_default();
        let body = info.get(10..)
            .map(|t| String::from_utf8_lossy(t).into_owned())
            .unwrap_or_default();

        let (text, id) = match body.rsplit_once('{') {
            Some((text, id)) if (1..=5).contains(&id.chars().count()) => {
                (text.to_string(), Some(id.to_string()))
            },
            _ => (body, None),
        };

        Self { addressee, text, id }
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
