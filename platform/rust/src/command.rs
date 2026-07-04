use ratatui::crossterm::event::KeyEvent;

#[derive(Debug)]
pub enum Command {
    AprsSendMessage(String),
    AprsSendStatus(String),
    Clear,
    Exit,
    Header(String),
    Help,
    Mycall(String),
    Net,
    Qso(String),
    Quit,
    UserKey(KeyEvent),
    OutputToTerminal(String),
}

