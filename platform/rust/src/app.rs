use ratatui::crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

#[derive(Debug)]
pub struct Command {
    pub kind: CommandKind,
    pub data: String,
}

#[derive(Debug)]
pub enum CommandKind {
    APRSSendMessage,
    APRSSendStatus,
}


#[derive(Debug, Default)]
pub struct App {
    pub should_quit: bool,
    pub counter: u8,
}

impl App {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn tick(&self) {}

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    pub fn increment_counter(&mut self) {
        if let Some(res) = self.counter.checked_add(1) {
            self.counter = res;
        }
    }

    pub fn decrement_counter(&mut self) {
        if let Some(res) = self.counter.checked_sub(1) {
            self.counter = res;
        }
    }

    pub fn handle_key(&mut self, key_event: KeyEvent) {
        match key_event.code {
            KeyCode::Esc | KeyCode::Char('q') => self.quit(),
            KeyCode::Char('c') | KeyCode::Char('C') if key_event.modifiers == KeyModifiers::CONTROL => {
                self.quit()
            }
            KeyCode::Right | KeyCode::Char('j') => self.increment_counter(),
            KeyCode::Left | KeyCode::Char('k') => self.decrement_counter(),
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

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_app_increment_counter() {
        let mut app = App::default();
        app.increment_counter();
        assert_eq!(app.counter, 1);
    }

    #[test]
    fn test_app_decrement_counter() {
        let mut app = App::default();
        app.decrement_counter();
        assert_eq!(app.counter, 0);
    }
}
