use color_eyre::Result;
use ratatui::crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use crate::{
    command::{Command, CommandKind},
    event::Event,
    tui::Tui,
    ui::MainUi,
};

#[derive(Debug, Default)]
pub struct App {
    pub should_quit: bool,
    main_ui: MainUi,
}

impl App {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn run(&mut self, tui: &mut Tui) -> Result<()> {
        while !self.should_quit {
            tui.draw(|frame| self.main_ui.render(frame))?;
            match tui.events.next()? {
                Event::Tick => {}
                Event::Key(key_event) => self.handle_key(key_event),
                Event::SendCommand(command) => self.handle_send_command(command),
            };
        }
        Ok(())
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    pub fn handle_key(&mut self, key_event: KeyEvent) {
        match key_event.code {
            KeyCode::Char('c') | KeyCode::Char('C') if key_event.modifiers == KeyModifiers::CONTROL => {
                self.quit()
            }
            //KeyCode::Right | KeyCode::Char('j') => self.increment_counter(),
            //KeyCode::Left | KeyCode::Char('k') => self.decrement_counter(),
            _ => {}
        };
    }

    pub fn handle_send_command(&mut self, command: Command) {
        match command.kind {
            CommandKind::APRSSendMessage => {}
            CommandKind::APRSSendStatus => {}
        };
    }

}

