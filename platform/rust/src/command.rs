use ratatui::crossterm::event::KeyEvent;

#[derive(Debug)]
pub enum Command {
    AprsSendMessage(String),
    AprsSendStatus(String),
    Clear,
    Exit,
    Help,
    Quit,
    UserKey(KeyEvent),
    OutputToTerminal(String),
}

