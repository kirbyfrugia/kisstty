use std::{ cell::Cell, collections::VecDeque, sync::mpsc };

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    text::Line,
    widgets::{
        Scrollbar, ScrollbarOrientation, ScrollbarState, StatefulWidget, Widget,
    },
};

use crate::{ event::Event, command::Command };

const MAX_OUTPUT_LINES: usize = 10000;

#[derive(Debug)]
enum ViewMode {
    Follow,
    Paused(usize),
}

#[derive(Debug)]
pub struct MultiLineOutput {
    _event_sender: mpsc::Sender<Event>,
    lines: VecDeque<String>,
    view_mode: ViewMode,
    max_scroll: Cell<usize>,
}

impl Widget for &MultiLineOutput {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let max_lines = area.height as usize;
        let total_lines = self.lines.len();

        let text_area = Rect { width: area.width.saturating_sub(1), ..area };

        let max_scroll = total_lines.saturating_sub(max_lines);
        self.max_scroll.set(max_scroll);

        let top = match self.view_mode {
            ViewMode::Follow => max_scroll,
            ViewMode::Paused(top) => top.min(max_scroll),
        };

        for (i, line) in self.lines.iter().skip(top).take(max_lines).enumerate() {
            let y = text_area.y + i as u16;
            buf.set_line(text_area.x, y, &Line::from(line.as_str()), text_area.width);
        }

        if total_lines > max_lines {
            let scrollbar = Scrollbar::default()
                .orientation(ScrollbarOrientation::VerticalRight);

            let mut scrollbar_state = ScrollbarState::new(max_scroll + 1)
                .viewport_content_length(max_lines)
                .position(top);

            scrollbar.render(area, buf, &mut scrollbar_state);
        }
    }
}

impl MultiLineOutput {
    pub fn new(event_sender: mpsc::Sender<Event>) -> Self {
        Self {
            _event_sender: event_sender,
            lines: VecDeque::with_capacity(MAX_OUTPUT_LINES),
            view_mode: ViewMode::Follow,
            max_scroll: Cell::new(0),
        }
    }

    pub fn add_line(&mut self, line: &str) {
        if self.lines.len() == MAX_OUTPUT_LINES {
            self.lines.pop_front();
            if let ViewMode::Paused(top) = &mut self.view_mode {
                // keep paused view scrolled to correct line
                // when we've wrapped the ring buffer
                *top = top.saturating_sub(1);
            }
        }
        self.lines.push_back(line.to_string());
    }

    pub fn is_following(&self) -> bool {
        matches!(self.view_mode, ViewMode::Follow)
    }

    pub fn toggle_view_mode(&mut self) {
        self.view_mode = match self.view_mode {
            ViewMode::Follow => {
                let top = self.max_scroll.get();
                ViewMode::Paused(top)
            },
            ViewMode::Paused(top) => ViewMode::Follow
        }
    }

    pub fn scroll_up(&mut self) {
        let top = match self.view_mode {
            ViewMode::Follow => self.max_scroll.get(),
            ViewMode::Paused(top) => top,
        };
        self.view_mode = ViewMode::Paused(top.saturating_sub(1));
    }

    pub fn scroll_down(&mut self) {
        let ViewMode::Paused(top) = self.view_mode else { return };
        if top + 1 >= self.max_scroll.get() {
            self.view_mode = ViewMode::Follow;
        } else {
            self.view_mode = ViewMode::Paused(top + 1);
        }
    }

    pub fn scroll_to_top(&mut self) {
        self.view_mode = ViewMode::Paused(0);
    }

    pub fn scroll_to_bottom(&mut self) {
        self.view_mode = ViewMode::Follow;
    }

    pub fn clear(&mut self) {
        self.lines.clear();
        self.view_mode = ViewMode::Follow;
    }

    pub fn try_handle(&mut self, command: &Command) -> bool {
        match command {
            Command::Clear => {
                self.clear();
                true
            },
            _ => false,
        }
    }
}
