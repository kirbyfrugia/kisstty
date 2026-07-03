use ratatui::crossterm::event::KeyEvent;

pub enum UiCommand {
    Key(KeyEvent),
}
