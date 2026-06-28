use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::Style,
    widgets::Widget,
};

#[derive(Debug)]
pub struct LineInput {
    visible_content: String,
}

impl Default for LineInput {
    fn default() -> Self {
        Self::new()
    }
}

impl Widget for &LineInput {
    fn render(self, area: Rect, buf: &mut Buffer) {
        buf.set_string(area.left(), area.top(), &self.visible_content, Style::default());
    }
}

impl LineInput {
    pub fn new() -> Self {
        Self {
            visible_content: String::from("howdy"),
        }
    }

    pub fn move_cursor_left(&mut self) {

    }

    pub fn move_cursor_right(&mut self) {

    }

}
