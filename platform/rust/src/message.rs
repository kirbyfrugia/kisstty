use ratatui::crossterm::event::KeyEvent;

use crate::{
    kiss::Ax25Frame,
    ui::{OutputUpdate, UiLine},
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
    Dump(u64),
    Exit,
    Help,
    Monitor,
    Net,
    Qso(String),
    Quit,
    Output(OutputUpdate),
    UpdateOutputLine(UiLine),
}
