use std::io;

use ratatui::{
    crossterm::{
        cursor::SetCursorStyle,
        execute,
    },
    layout::Size,
    Frame,
};

use crate::{
    command::Command,
    config::Config,
    event::{Event, EventHandler},
    ui::{ConfigUi, MainUi, TooSmallUi},
};

#[derive(Debug)]
enum Screen {
    Main,
    Config,
}

#[derive(Debug)]
pub struct App {
    pub should_quit: bool,
    events: EventHandler,
    active_screen: Screen,
    too_small: bool,
    too_small_ui: TooSmallUi,
    main_ui: MainUi,
    config_ui: ConfigUi,
}

impl App {
    pub fn new() -> Self {
        let events = EventHandler::new(250);
        let events_sender = events.sender();
        let main_ui = MainUi::new(events_sender.clone());
        let config_ui = ConfigUi::new(events_sender.clone());
        let too_small_ui = TooSmallUi::new(events_sender);
        Self {
            should_quit: false,
            events,
            active_screen: Screen::Main,
            too_small: false,
            too_small_ui,
            main_ui,
            config_ui,
        }
    }

    pub fn run(&mut self) -> color_eyre::Result<()> {
        ratatui::run(|terminal| -> color_eyre::Result<()> {
            execute!(io::stdout(), SetCursorStyle::BlinkingBar)?;
            let _config = Config::load();
            while !self.should_quit {
                terminal.draw(|frame| self.render(frame))?;

                match self.events.next()? {
                    Event::Tick => self.tick(),
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

    fn render(&mut self, frame: &mut Frame) {
        let area = frame.area();
        let min = Self::min_size();
        self.too_small = area.width < min.width || area.height < min.height;

        if self.too_small {
            self.too_small_ui.render(frame);
            return;
        }

        match self.active_screen {
            Screen::Main => self.main_ui.render(frame),
            Screen::Config => self.config_ui.render(frame),
        }
    }

    fn min_size() -> Size {
        Size {
            width: MainUi::MIN_SIZE.width.max(ConfigUi::MIN_SIZE.width),
            height: MainUi::MIN_SIZE.height.max(ConfigUi::MIN_SIZE.height),
        }
    }

    fn tick(&mut self) {
        match self.active_screen {
            Screen::Main => self.main_ui.tick(),
            Screen::Config => self.config_ui.tick(),
        }
    }

    fn handle_command(&mut self, command: Command) {
        if self.try_handle(&command) { return }
        if self.route(&command) { return }

        tracing::warn!("unhandled command: {:?}", command);
    }

    fn try_handle(&mut self, command: &Command) -> bool {
        match command {
            Command::Exit | Command::Quit => {
                self.quit();
                true
            },
            Command::Config => {
                self.active_screen = Screen::Config;
                true
            },
            Command::ConfigSaved | Command::ConfigCanceled => {
                self.active_screen = Screen::Main;
                true
            },
            _ => false,
        }
    }

    fn route(&mut self, command: &Command) -> bool {
        if self.too_small {
            return self.too_small_ui.try_handle(command);
        }

        match self.active_screen {
            Screen::Main => self.main_ui.try_handle(command),
            Screen::Config => self.config_ui.try_handle(command),
        }
    }

}
