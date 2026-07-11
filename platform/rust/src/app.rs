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
    kiss::{KissClient,KissSession},
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
    kiss_client: Option<KissClient>,
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
            kiss_client: None,
            kiss_session,
        }
    }

    fn start_kiss(&mut self) {
        if self.kiss_client.is_some() {
            return;
        }
        self.kiss_client = Some(KissClient::new(
            self.config.kiss_host.clone(),
            self.config.kiss_port,
            self.events.sender(),
        ));
    }

    fn restart_kiss(&mut self) {
        self.kiss_client = None;
        self.start_kiss();
    }

    fn set_active_screen(&mut self, screen: Screen) {
        match screen {
            Screen::Main => self.main_ui.update_config(&mut self.config),
            _ => {}
        }
        self.active_screen = screen;
    }

    pub fn run(&mut self) -> color_eyre::Result<()> {
        ratatui::run(|terminal| -> color_eyre::Result<()> {
            execute!(io::stdout(), SetCursorStyle::BlinkingBar)?;
            self.config = Config::load()?;

            // on first run, make sure they enter a callsign
            // and valid kiss host
            if self.config.callsign.trim().is_empty() {
                self.config_ui.load_config(&self.config);
                self.set_active_screen(Screen::Config);
            } else {
                self.set_active_screen(Screen::Main);
                self.start_kiss();
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
        if self.try_handle(&message) { return }

        // TODO: move much of this to session.rs or kiss client
        match message {
            Message::SendAx25Frame(frame) => {
                match &self.kiss_client {
                    Some(kiss_client) => kiss_client.send(frame),
                    None => tracing::warn!("no kiss connection; dropping outgoing frame"),
                }
            },
            Message::Ax25FrameReceived(ax25_frame) => {
                self.kiss_session.frame_received(ax25_frame);
            },
            _ => { self.route(&message); },
        }
    }

    fn try_handle(&mut self, message: &Message) -> bool {
        match message {
            Message::Exit | Message::Quit => {
                self.quit();
                true
            },
            Message::Config => {
                self.config_ui.load_config(&self.config);
                self.set_active_screen(Screen::Config);
                true
            },
            Message::ConfigSaved => {
                self.config_ui.apply_to(&mut self.config);
                if let Err(e) = self.config.save() {
                    tracing::error!(?e, "failed to save config");
                }
                self.main_ui.update_config(&mut self.config);
                self.restart_kiss();
                self.set_active_screen(Screen::Main);
                true
            },
            Message::ConfigCanceled => {
                if self.config.callsign.trim().is_empty() {
                    self.quit();
                } else {
                    self.set_active_screen(Screen::Main);
                }
                true
            },
            _ => false,
        }
    }

    fn route(&mut self, message: &Message) -> bool {
        if self.too_small {
            return self.too_small_ui.try_handle(message);
        }

        match self.active_screen {
            Screen::Main => self.main_ui.try_handle(message),
            Screen::Config => self.config_ui.try_handle(message),
        }
    }

}
