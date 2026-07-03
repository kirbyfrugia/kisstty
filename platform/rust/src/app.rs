use std::io;

use ratatui::{
    crossterm::{
        cursor::SetCursorStyle,
        event::{
            KeyCode,
            KeyEvent,
            KeyModifiers
        },
        execute,
    },
};

use crate::{
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
                    Event::Key(key_event) => self.handle_key(key_event),
//                    Event::SendCommand(command) => self.handle_send_command(command),
                    Event::Quit => self.quit()
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

    pub fn handle_key(&mut self, key_event: KeyEvent) {
        match key_event.code {
            KeyCode::Char('c') | KeyCode::Char('C') if key_event.modifiers == KeyModifiers::CONTROL => {
                self.quit()
            },
            _ => self.main_ui.handle_key(key_event),
        };
    }

//    pub fn handle_send_command(&mut self, command: Command) {
//        match command.kind {
//            CommandKind::APRSSendMessage => {}
//            CommandKind::APRSSendStatus => {}
//        };
//    }

}

