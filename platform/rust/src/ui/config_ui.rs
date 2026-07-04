use std::sync::mpsc;

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent},
    layout::{Alignment, Constraint, Direction, Layout, Size},
    style::{Modifier, Style},
    widgets::{Block, Borders, Paragraph},
    Frame,
};

use crate::{
    command::Command,
    event::Event,
};

#[derive(Debug, Clone, Copy, PartialEq)]
enum Button {
    Cancel,
    Save,
}

fn button_label(label: &str) -> String {
    format!("[ {} ]", label)
}

#[derive(Debug)]
pub struct ConfigUi {
    event_sender: mpsc::Sender<Event>,
    selected_button: Button,
}

impl ConfigUi {
    pub const MIN_SIZE: Size = Size { width: 40, height: 10 };

    pub fn new(event_sender: mpsc::Sender<Event>) -> Self {
        Self {
            event_sender,
            selected_button: Button::Save,
        }
    }

    pub fn render(&mut self, frame: &mut Frame) {
        let block = Block::default()
            .title("kisstty (config)")
            .title_alignment(Alignment::Left)
            .borders(Borders::ALL);

        let inner = block.inner(frame.area());
        frame.render_widget(block, frame.area());

        let layout = Layout::default()
            .direction(Direction::Vertical)
            .constraints(vec![
                Constraint::Fill(1),   // body
                Constraint::Length(1), // buttons
            ])
            .split(inner);

        let body = Paragraph::new("Config")
            .style(Style::default())
            .alignment(Alignment::Center);

        frame.render_widget(body, layout[0]);

        let buttons = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(vec![
                Constraint::Fill(1),
                Constraint::Length(button_label("Cancel").len() as u16),
                Constraint::Length(1),
                Constraint::Length(button_label("Save").len() as u16),
                Constraint::Fill(1),
            ])
            .split(layout[1]);

        frame.render_widget(self.button("Cancel", Button::Cancel), buttons[1]);
        frame.render_widget(self.button("Save", Button::Save), buttons[3]);
    }

    fn button(&self, label: &str, which_button: Button) -> Paragraph<'static> {
        let style = if self.selected_button == which_button {
            Style::default().add_modifier(Modifier::REVERSED)
        } else {
            Style::default()
        };

        Paragraph::new(button_label(label)).style(style)
    }

    pub fn tick(&mut self) {
    }

    pub fn try_handle(&mut self, command: &Command) -> bool {
        match command {
            Command::UserKey(key_event) => self.handle_key(key_event),
            _ => false,
        }
    }

    fn handle_key(&mut self, key_event: &KeyEvent) -> bool {
        match key_event.code {
            KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                self.selected_button = match self.selected_button {
                    Button::Save => Button::Cancel,
                    Button::Cancel => Button::Save,
                };
            }
            KeyCode::Enter => self.select(self.selected_button),
            KeyCode::Esc => self.select(Button::Cancel),
            _ => return false,
        }
        true
    }

    fn select(&mut self, button: Button) {
        let command = match button {
            Button::Save => Command::ConfigSaved,
            Button::Cancel => Command::ConfigCanceled,
        };
        let _ = self.event_sender.send(Event::SendCommand(command));
    }
}
