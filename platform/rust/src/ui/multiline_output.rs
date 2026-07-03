use std::{ cmp, sync::mpsc };

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::Style,
    widgets::Widget,
};

use crate::{ event::Event };

#[derive(Debug)]
pub struct Output {
    _event_sender:       mpsc::Sender<Event>,
}

impl Widget for &MultilineOutput {
    fn render(self, area: Rect, buf: &mut Buffer) {

    }
}

impl MultilineOutput {
    pub fn new(event_sender: mpsc::Sender<Event>) -> Self {
        Self {
            _event_sender: event_sender,
        }
    }

    pub fn add_line(&self) {
        
    }

}
