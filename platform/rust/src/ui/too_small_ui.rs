use std::sync::mpsc;

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent, KeyModifiers},
    layout::Alignment,
    style::Style,
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame,
};

use crate::{
    command::Command,
    event::Event,
};

#[derive(Debug)]
pub struct TooSmallUi {
    event_sender: mpsc::Sender<Event>,
}

impl TooSmallUi {
    pub fn new(event_sender: mpsc::Sender<Event>) -> Self {
        Self { event_sender }
    }

    pub fn render(&mut self, frame: &mut Frame) {
        let warning = Paragraph::new("Make the terminal window bigger.")
            .block(
                Block::default()
                    .title("kisstty")
                    .title_alignment(Alignment::Center)
                    .borders(Borders::ALL)
            )
            .style(Style::default())
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true });

        frame.render_widget(warning, frame.area());
    }

    pub fn try_handle(&mut self, command: &Command) -> bool {
        match command {
            Command::UserKey(key_event) => self.handle_key(key_event),
            _ => false,
        }
    }

    fn handle_key(&mut self, key_event: &KeyEvent) -> bool {
        match key_event.code {
            KeyCode::Esc => self.quit(),
            KeyCode::Char('c') | KeyCode::Char('C')
                if key_event.modifiers == KeyModifiers::CONTROL => self.quit(),
            _ => return false,
        }
        true
    }

    fn quit(&mut self) {
        let _ = self.event_sender.send(Event::SendCommand(Command::Quit));
    }
}
