use color_eyre::Result;
use ratatui::{
    crossterm::event::{
        self,
        KeyCode,
        KeyEvent,
        KeyModifiers
    },
    Frame,
};



use crate::{
    event::{Event, EventHandler},
    command::{Command, CommandKind},
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

    pub fn run(&mut self) -> color_eyre::Result<()> {
        let events = EventHandler::new(250);
        ratatui::run(|terminal| -> color_eyre::Result<()> {
            while !self.should_quit {
                terminal.draw(|frame| self.main_ui.render(frame))?;

                match events.next()? {
                    Event::Tick => {}
                    Event::Key(key_event) => self.handle_key(key_event),
                    Event::SendCommand(command) => self.handle_send_command(command),
                };
            }
            Ok(())
        })?;

        Ok(())
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    pub fn handle_key(&mut self, key_event: KeyEvent) {
        match key_event.code {
            KeyCode::Char('c') | KeyCode::Char('C') if key_event.modifiers == KeyModifiers::CONTROL => {
                self.quit()
            },
            _ => self.main_ui.handle_key(key_event),
        };
    }

    pub fn handle_send_command(&mut self, command: Command) {
        match command.kind {
            CommandKind::APRSSendMessage => {}
            CommandKind::APRSSendStatus => {}
        };
    }

}

