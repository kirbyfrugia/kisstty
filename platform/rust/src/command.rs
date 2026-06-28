#[derive(Debug)]
pub struct Command {
    #[allow(dead_code)]
    pub kind: CommandKind,
    #[allow(dead_code)]
    pub data: String,
}

#[derive(Debug)]
pub enum CommandKind {
    #[allow(dead_code)]
    APRSSendMessage,
    #[allow(dead_code)]
    APRSSendStatus,
}
