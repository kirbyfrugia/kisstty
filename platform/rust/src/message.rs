use ratatui::crossterm::event::KeyEvent;

use crate::{
    kiss::AprsMessage,
    kiss::Ax25Frame,
    ui::OutputUpdate,
};

#[derive(Debug)]
pub enum Message {
    Tick,
    UserKey(KeyEvent),
    ConfigSaved,
    ConfigCanceled,
    AprsMessage(AprsMessage),
    Ax25FrameReceived(Ax25Frame),
    SendAx25Frame(Ax25Frame),
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
