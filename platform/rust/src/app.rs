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
    config::Config,
    event::EventHandler,
    kiss::KissSession,
    message::Message,
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
    config: Config,
    kiss_session: KissSession,
}

impl App {
    pub fn new() -> Self {
        let events = EventHandler::new(250);
        let events_sender = events.sender();
        let main_ui = MainUi::new(events_sender.clone());
        let config_ui = ConfigUi::new(events_sender.clone());
        let too_small_ui = TooSmallUi::new(events_sender.clone());
        let kiss_session = KissSession::new(events_sender.clone());
        Self {
            should_quit: false,
            events,
            active_screen: Screen::Main,
            too_small: false,
            too_small_ui,
            main_ui,
            config_ui,
            config: Config::default(),
            kiss_session,
        }
    }

    fn set_active_screen(&mut self, screen: Screen) {
        self.active_screen = screen;
    }

    pub fn run(&mut self) -> color_eyre::Result<()> {
        ratatui::run(|terminal| -> color_eyre::Result<()> {
            execute!(io::stdout(), SetCursorStyle::BlinkingBar)?;
            self.config = Config::load()?;

            if self.config.validate().is_ok() {
                self.set_active_screen(Screen::Main);
                self.kiss_session.start(&self.config);
            } else {
                self.config_ui.load_config(&self.config);
                self.set_active_screen(Screen::Config);
            }

            while !self.should_quit {
                terminal.draw(|frame| self.render(frame))?;

                match self.events.next()? {
                    Message::Tick => self.tick(),
                    message => self.handle_message(message),
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

    fn handle_message(&mut self, message: Message) {
        let Some(message) = self.try_claim(message) else { return };
        let Some(message) = self.kiss_session.try_claim(message) else { return };
        let Some(message) = self.main_ui.try_claim(message) else { return };

        if let Some(message) = self.route(message) {
            tracing::debug!(?message, "unclaimed message");
        }
    }

    fn try_claim(&mut self, message: Message) -> Option<Message> {
        match message {
            Message::Exit | Message::Quit => {
                self.quit();
                None
            },
            Message::Config => {
                self.config_ui.load_config(&self.config);
                self.set_active_screen(Screen::Config);
                None
            },
            Message::ConfigSaved => {
                self.config_ui.apply_to(&mut self.config);
                if let Err(e) = self.config.save() {
                    tracing::error!(?e, "failed to save config");
                }
                self.kiss_session.restart(&self.config);
                self.set_active_screen(Screen::Main);
                None
            },
            Message::ConfigCanceled => {
                if self.config.validate().is_err() {
                    self.quit();
                } else {
                    self.set_active_screen(Screen::Main);
                }
                None
            },
            other => Some(other),
        }
    }

    fn route(&mut self, message: Message) -> Option<Message> {
        if self.too_small {
            return self.too_small_ui.try_claim(message);
        }

        match self.active_screen {
            Screen::Main => self.main_ui.try_claim_while_active(message),
            Screen::Config => self.config_ui.try_claim_while_active(message),
        }
    }

}
