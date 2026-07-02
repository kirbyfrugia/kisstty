use std::cmp;

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent},
    layout::{
        Alignment,
        Constraint,
        Direction,
        Layout,
        Position,
        Rect,
        Spacing,
    },
    style::{
        Color,
        Modifier,
        Style,
    },
    widgets::{
        Block,
        Borders,
        Clear,
        List,
        ListState,
        Paragraph,
        Wrap,
    },
    symbols::merge::MergeStrategy,
    Frame,
};

use crate::ui::LineInput;

const MAX_INPUT_LEN:  usize = 80;
const TERMINAL_WIDTH: u16   = 80;
const SIDEBAR_WIDTH:  u16   = 26;
const MIN_APP_WIDTH:  u16   = (TERMINAL_WIDTH + 4) + (SIDEBAR_WIDTH + 2);
const SLASH_COMMANDS_COMMON: [&str; 3] = [
    "/mycall",
    "/net",
    "/qso",
];

#[derive(Debug)]
pub struct MainUi {
    line_input: LineInput,
}

impl Default for MainUi {
    fn default() -> Self {
        Self {
            line_input: LineInput::new(MAX_INPUT_LEN, TERMINAL_WIDTH.into()),
        }
    }
}

impl MainUi {
    fn render_too_small(&mut self, frame: &mut Frame) {
        let warning = Paragraph::new("Terminal window too small. Make it wider.")
            .block(
                Block::default()
                    .title("kisstty")
                    .title_alignment(Alignment::Center)
                    .borders(Borders::ALL)
            )
            .style(Style::default())
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true });
    
        frame.render_widget(warning, frame.area());
    }

    fn render_slash_popup(&mut self, frame: &mut Frame, inputx: u16, inputy: u16) {
        let matching: Vec<_> = SLASH_COMMANDS_COMMON
            .into_iter()
            .filter(|cmd_str| cmd_str.starts_with(&self.line_input.data))
            .collect();

        let num_matching: u16 = matching.len().try_into().unwrap();

        if num_matching == 0 { return }

        let mut max_len: u16 = matching
            .iter()
            .map(|cmd_str| cmd_str.len())
            .max()
            .unwrap_or(3).try_into().unwrap();

        max_len += 3; // + prompt and a space

        let popup_height: u16 = cmp::min(num_matching, 2);
        tracing::info!(popup_height, "popup height");

        let area = Rect {
            x: inputx,
            y: inputy - (popup_height+1),
            width: max_len,
            height: popup_height,
        };
        frame.render_widget(Clear, area);

        let mut list_state = ListState::default().with_selected(Some(0));

        let list = List::new(matching)
            .style(Color::White)
            .highlight_style(Modifier::REVERSED)
            .highlight_symbol("> ");

        frame.render_stateful_widget(list, area, &mut list_state);

    }

    fn render_full_ui(&mut self, frame: &mut Frame) {
        let window_layout = Layout::default()
            .direction(Direction::Horizontal)
            .spacing(Spacing::Overlap(1))
            .constraints(vec![
                Constraint::Fill(1),
                Constraint::Length(MIN_APP_WIDTH),
                Constraint::Fill(1),
            ])
            .split(frame.area());

        // app layout has the area for the main output terminal
        // and a sidebar to show the user information.
        let app_layout = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(vec![
                Constraint::Length(TERMINAL_WIDTH+2+2), // left side with room
                                                        // for borders, caret,
                                                        // space, etc.
                Constraint::Length(SIDEBAR_WIDTH+2),    // right sidebar
            ])
            .split(window_layout[1]);

        let terminal_layout = Layout::default()
            .direction(Direction::Vertical)
            .spacing(Spacing::Overlap(1))
            .constraints(vec![
                Constraint::Fill(1),   // output
                Constraint::Length(3), // input plus top/bottom border
            ])
            .split(app_layout[0]);

        let terminal_output = Paragraph::new(format!("NOCALL>NOCALL:message"))
            .block(
                Block::default()
                    .title("kisstty (net)")
                    .title_alignment(Alignment::Left)
                    .borders(Borders::ALL)
                    .merge_borders(MergeStrategy::Exact),
            )
            .style(Style::default())
            .alignment(Alignment::Left);

        frame.render_widget(terminal_output, terminal_layout[0]);

        let terminal_input_block = Block::bordered()
            .style(Style::default())
            .merge_borders(MergeStrategy::Exact);

        frame.render_widget(&terminal_input_block, terminal_layout[1]);

        let terminal_input_block_inner_area = terminal_input_block.inner(terminal_layout[1]);
        let terminal_input_layout = Layout::default()
            .direction(Direction::Horizontal)
            .spacing(Spacing::Overlap(1))
            .constraints(vec![
                Constraint::Length(3),              // prompt
                Constraint::Length(TERMINAL_WIDTH),
            ])
            .split(terminal_input_block_inner_area);

        let terminal_input_prompt = Paragraph::new(format!("> "))
            .style(Style::default())
            .alignment(Alignment::Left);

        frame.render_widget(terminal_input_prompt, terminal_input_layout[0]);
        frame.render_widget(&self.line_input, terminal_input_layout[1]);

        let terminal_input_area = terminal_input_layout[1];
        let cursor_pos = Position{
            x: terminal_input_area.x + self.line_input.screen_cursor as u16,
            y: terminal_input_area.y,
        };
        frame.set_cursor_position(cursor_pos);

        let sidebar = Paragraph::new("Callsign:\n\nActive QSOs:\nABC123\nXYZ456")
            .block(
                Block::default()
                    .title("blah")
                    .title_alignment(Alignment::Left)
                    .borders(Borders::ALL)
                    .merge_borders(MergeStrategy::Exact),
            )
            .style(Style::default())
            .alignment(Alignment::Left);

        frame.render_widget(sidebar, app_layout[1]);

        let is_slash = self.line_input.is_typing_slash_command();
        tracing::info!(is_slash, "is slash");

        if is_slash {
            self.render_slash_popup(
                frame, 
                terminal_input_block_inner_area.x,
                terminal_input_block_inner_area.y,
            );
        }

    }

    pub fn render(&mut self, frame: &mut Frame) {
        if frame.area().width < MIN_APP_WIDTH {
            self.render_too_small(frame);
        } else {
            self.render_full_ui(frame);
        }
    }

    pub fn handle_key(&mut self, key_event: KeyEvent) {
        match key_event.code {
            KeyCode::Left => self.line_input.move_cursor_left(),
            KeyCode::Right => self.line_input.move_cursor_right(),
            KeyCode::Delete => self.line_input.delete_char(),
            KeyCode::Backspace => self.line_input.backspace(),
            KeyCode::Char(c) => {
                self.line_input.insert_char(c);
            }
            _ => { },

        };
    }

}
