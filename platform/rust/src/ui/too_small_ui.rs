use std::sync::mpsc;

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent, KeyModifiers},
    layout::Alignment,
    style::{Modifier, Style},
    widgets::{Block, BorderType, Borders, Paragraph, Wrap},
    Frame,
};

use crate::message::Message;

#[derive(Debug)]
pub struct TooSmallUi {
    message_sender: mpsc::Sender<Message>,
}

impl TooSmallUi {
    pub fn new(message_sender: mpsc::Sender<Message>) -> Self {
        Self { message_sender }
    }

    pub fn render(&mut self, frame: &mut Frame) {
        let warning = Paragraph::new("Make the terminal window bigger.")
            .block(
                Block::default()
                    .title(" kisstty ")
                    .title_style(Style::default().add_modifier(Modifier::REVERSED))
                    .title_alignment(Alignment::Center)
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
            )
            .style(Style::default())
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true });

        frame.render_widget(warning, frame.area());
    }

    pub fn try_claim(&mut self, message: Message) -> Option<Message> {
        match message {
            Message::UserKey(key_event) => self.handle_key(key_event),
            other => Some(other),
        }
    }

    fn handle_key(&mut self, key_event: KeyEvent) -> Option<Message> {
        match key_event.code {
            KeyCode::Esc => self.quit(),
            KeyCode::Char('c') | KeyCode::Char('C')
                if key_event.modifiers == KeyModifiers::CONTROL => self.quit(),
            _ => return Some(Message::UserKey(key_event)),
        }
        None
    }

    fn quit(&mut self) {
        let _ = self.message_sender.send(Message::Quit);
    }
}
