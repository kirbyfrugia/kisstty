use ratatui::crossterm::event::KeyEvent;

#[derive(Debug)]
pub enum Command {
    AprsSendMessage(String),
    AprsSendStatus(String),
    Clear,
    Config,
    ConfigCanceled,
    ConfigSaved,
    Exit,
    Header(String),
    Help,
    Net,
    Qso(String),
    Quit,
    UserKey(KeyEvent),
    OutputToTerminal(String),
}

