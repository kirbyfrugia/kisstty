use ratatui::crossterm::event::KeyEvent;

#[derive(Debug)]
// A mix of commands (do X) and events (X happened)
pub enum Message {
    Tick,
    UserKey(KeyEvent),
    ConfigSaved,
    ConfigCanceled,
    AprsSendMessage(String),
    AprsSendStatus(String),
    Clear,
    Config,
    Exit,
    Header(String),
    Help,
    Net,
    Qso(String),
    Quit,
    OutputToTerminal(String),
}
