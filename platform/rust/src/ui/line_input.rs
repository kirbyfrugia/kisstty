use ratatui::{
    buffer::Buffer,
    layout::{Position, Rect},
    style::Style,
    widgets::Widget,
};

#[derive(Debug)]
pub struct LineInput {
    pub cursor_pos:  Position,
    visible_content: String,
    data_cursor:     u16,
    first_visible:   u16,
    pub max_len:     u16,
}

impl Default for LineInput {
    fn default() -> Self {
        Self {
            visible_content: String::default(),
            cursor_pos: Position::default(),
            data_cursor: 0,
            first_visible: 0,
            max_len: 0,
        }
    }
}

impl Widget for &LineInput {
    fn render(self, area: Rect, buf: &mut Buffer) {
        buf.set_string(area.left(), area.top(), &self.visible_content, Style::default());
    }
}

impl LineInput {
    pub fn new(max_len: u16) -> Self {
        Self {
            max_len,
            ..Self::default()
        }
    }

    pub fn move_cursor_left(&mut self) {
        if self.cursor_pos.x == 0 { return }
        self.cursor_pos.x = self.cursor_pos.x - 1;
    }

    pub fn move_cursor_right(&mut self) {
        tracing::info!(self.cursor_pos.x, self.max_len, "cursor pos");
        if self.cursor_pos.x + 1 >= self.max_len { return }
        self.cursor_pos.x = self.cursor_pos.x + 1;
    }

}
