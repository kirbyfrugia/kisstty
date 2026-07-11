use ratatui::crossterm::event::KeyEvent;

use crate::{
    kiss::Ax25Frame,
    ui::OutputUpdate,
};

#[derive(Debug)]
pub enum Message {
    Tick,
    UserKey(KeyEvent),
    ConfigSaved,
    ConfigCanceled,
    Ax25FrameReceived(Ax25Frame),
    SendAprsMessage { addressee: String, text: String },
    Clear,
    Config,
    Exit,
    Header(String),
    Help,
    Net,
    Qso(String),
    Quit,
    Output(OutputUpdate),
}
