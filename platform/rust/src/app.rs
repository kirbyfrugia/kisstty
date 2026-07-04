use std::io;

use ratatui::{
    crossterm::{
        cursor::SetCursorStyle,
        execute,
    },
};

use crate::{
    command::Command,
    event::{Event, EventHandler},
    ui::MainUi,
};

#[derive(Debug)]
pub struct App {
    pub should_quit: bool,
    events: EventHandler,
    main_ui: MainUi,
}

impl App {
    pub fn new() -> Self {
        let events = EventHandler::new(250);
        let events_sender = events.sender();
        let main_ui = MainUi::new(events_sender);
        Self {
            should_quit: false,
            events,
            main_ui,
        }
    }

    pub fn run(&mut self) -> color_eyre::Result<()> {
        ratatui::run(|terminal| -> color_eyre::Result<()> {
            execute!(io::stdout(), SetCursorStyle::BlinkingBar)?;

            while !self.should_quit {
                terminal.draw(|frame| self.main_ui.render(frame))?;

                match self.events.next()? {
                    Event::Tick =>  self.main_ui.tick(),
                    Event::SendCommand(command) => self.handle_command(command),
                };
            }
            Ok(())
        })?;

        execute!(io::stdout(), SetCursorStyle::DefaultUserShape)?;

        Ok(())
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    fn handle_command(&mut self, command: Command) {
        if self.try_handle(&command) { return }
        if self.main_ui.try_handle(&command) { return }

        tracing::warn!("unhandled command: {:?}", command);
    }

    fn try_handle(&mut self, command: &Command) -> bool {
        match command {
            Command::Exit | Command::Quit => {
                self.quit();
                true
            },
            _ => false,
        }
    }

}

