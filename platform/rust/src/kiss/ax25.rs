use super::aprs::AprsData;

#[derive(Debug)]
pub struct Ax25Addr {
    addr: String,
    ssid: u8,
    pub last_addr: bool,
}

impl Ax25Addr {
    fn process_addr(buf: &[u8; 7]) -> String {
        let mut addr = String::new();
        for &byte in &buf[0..6] {
            let shifted = byte >> 1;
            let byte_char = shifted as char;
            addr.push(byte_char);
        }

        return String::from(addr.trim_end());
    }

    pub fn new(buf: &[u8; 7]) -> Self {
        let addr = Self::process_addr(buf);
        let ssid = (buf[6] >> 1) & 0b0000_1111;

        // this is the last address in the header if
        // the lsb on byte 6 is 0.
        let last_byte = buf[6];
        let last_addr = last_byte & 0b0000_0001 != 0;

        Self {
            addr,
            ssid,
            last_addr
        }
    }
}

impl std::fmt::Display for Ax25Addr {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.ssid != 0 {
            write!(f, "{}-{}", self.addr, self.ssid)
        } else {
            write!(f, "{}", self.addr)
        }
    }
}

#[derive(Debug)]
pub struct Ax25Frame {
    #[allow(dead_code)]
    dest: Ax25Addr,
    source: Ax25Addr,
    #[allow(dead_code)]
    digipeaters: Vec<Ax25Addr>,
    #[allow(dead_code)]
    control: u8,
    #[allow(dead_code)]
    pid: u8,
    data: AprsData,
}

impl Ax25Frame {
    pub fn parse(bytes: &[u8]) -> Option<Self> {
        const MIN_AX25_FRAME_SIZE: usize = 16; // source + dest + ctrl + pid
        if bytes.len() < MIN_AX25_FRAME_SIZE {
            tracing::warn!(len = bytes.len(), "discarding invalid ax25 frame - too small");
            return None
        }

        const MAX_AX25_ADDRS: usize = 10;
        let mut addrs: Vec<Ax25Addr> = Vec::new();
        let mut offset = 0;
        while addrs.len() < MAX_AX25_ADDRS && offset + 7 <= bytes.len() {
            let addr = Ax25Addr::new(bytes[offset..offset + 7].try_into().unwrap());
            let last_addr = addr.last_addr;
            addrs.push(addr);
            if last_addr { break }
            offset += 7;
        }

        let mut addrs = addrs.into_iter();
        let control_field_start = addrs.len() * 7;

        let Some(dest) = addrs.next() else {
            tracing::warn!("ax25 frame missing dest field");
            return None
        };

        let Some(source) = addrs.next() else {
            tracing::warn!("ax25 frame missing source field");
            return None
        };

        let digipeaters = addrs.collect();

        let Some(&control) = bytes.get(control_field_start) else {
            tracing::warn!("ax25 frame missing control byte");
            return None
        };
        let Some(&pid) = bytes.get(control_field_start + 1) else {
            tracing::warn!("ax25 frame missing pid byte");
            return None
        };

        let info_field_start = control_field_start + 2;
        let info = bytes.get(info_field_start..).unwrap_or(&[]);
        let data = AprsData::parse(info);

        Some(Ax25Frame { dest, source, digipeaters, control, pid, data })
    }

    pub fn header(&self) -> String {
        match &self.data {
            AprsData::Message(msg) => format!("{}>{}", self.source, msg.addressee),
            _ => self.source.to_string(),
        }
    }

    pub fn body(&self) -> &str {
        match &self.data {
            AprsData::Message(msg) => &msg.text,
            AprsData::Status(status) => &status.text,
            AprsData::Unknown => "<unknown>",
        }
    }
}
