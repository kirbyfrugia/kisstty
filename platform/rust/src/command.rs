#[derive(Debug)]
pub enum CommandKind {
    APRSSendMessage,
    APRSSendStatus,
}

#[derive(Debug)]
pub struct Command {
    pub command: &'static CommandKind,
    pub friendly: &'static str,
    pub data: String,
}


