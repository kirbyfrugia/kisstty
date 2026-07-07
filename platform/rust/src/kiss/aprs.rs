#[derive(Debug)]
pub enum AprsData {
    #[allow(dead_code)]
    Message(AprsMessage),
    #[allow(dead_code)]
    Status(AprsStatus),
    Unknown,
}

#[derive(Debug)]
pub struct AprsMessage {
    #[allow(dead_code)]
    pub addressee: String,
    #[allow(dead_code)]
    pub text: String,
}

#[derive(Debug)]
pub struct AprsStatus {
    #[allow(dead_code)]
    pub text: String,
}

impl AprsData {
    pub fn parse(info: &[u8]) -> Self {
        let Some((&data_type_id, rest)) = info.split_first() else {
            return AprsData::Unknown;
        };

        match data_type_id {
            b':' => AprsData::Message(AprsMessage::parse(rest)),
            b'>' => AprsData::Status(AprsStatus::parse(rest)),
            _ => AprsData::Unknown,
        }
    }
}

impl AprsMessage {
    fn parse(info: &[u8]) -> Self {
        let addressee = info.get(0..9)
            .map(|a| String::from_utf8_lossy(a).trim_end().to_string())
            .unwrap_or_default();
        let text = info.get(10..)
            .map(|t| String::from_utf8_lossy(t).into_owned())
            .unwrap_or_default();

        Self { addressee, text }
    }
}

impl AprsStatus {
    fn parse(info: &[u8]) -> Self {
        Self {
            text: String::from_utf8_lossy(info).into_owned(),
        }
    }
}
