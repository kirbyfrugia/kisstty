use ratatui::{
    crossterm::event::{KeyCode, KeyEvent},
    layout::{Alignment, Constraint, Direction, Layout, Position, Spacing},
    style::{Color, Style},
    widgets::{Block, Borders, Paragraph, Wrap},
    symbols::merge::MergeStrategy,
    Frame,
};

use crate::ui::LineInput;

const TERMINAL_WIDTH: u16 = 80;
const SIDEBAR_WIDTH:  u16 = 26;
const MIN_APP_WIDTH:  u16 = (TERMINAL_WIDTH + 2) + (SIDEBAR_WIDTH + 2);

#[derive(Debug)]
pub struct MainUi {
    line_input: LineInput,
}

impl Default for MainUi {
    fn default() -> Self {
        Self {
            line_input: LineInput::new(TERMINAL_WIDTH),
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
            .style(Style::default().fg(Color::Yellow))
            .alignment(Alignment::Center)
            .wrap(Wrap { trim: true });
    
        frame.render_widget(warning, frame.area());
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

        let app_layout = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(vec![
                Constraint::Length(TERMINAL_WIDTH+2), // left side
                Constraint::Length(SIDEBAR_WIDTH+2),  // right side
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

        let output = Paragraph::new(format!("NOCALL>NOCALL:some message"))
            .block(
                Block::default()
                    .title("kisstty")
                    .title_alignment(Alignment::Left)
                    .borders(Borders::ALL)
                    .merge_borders(MergeStrategy::Exact),
            )
            .style(Style::default().fg(Color::Yellow))
            .alignment(Alignment::Left);

        frame.render_widget(output, terminal_layout[0]);

        let input_block = Block::bordered()
            .style(Style::default().fg(Color::Yellow))
            .merge_borders(MergeStrategy::Exact);


        let input_inner_area = input_block.inner(terminal_layout[1]);
        frame.render_widget(input_block, terminal_layout[1]);
        frame.render_widget(&self.line_input, input_inner_area);

        let temp = Paragraph::new("Callsign: ")
            .block(
                Block::default()
                    .title("blah")
                    .title_alignment(Alignment::Left)
                    .borders(Borders::ALL)
                    .merge_borders(MergeStrategy::Exact),
            )
            .style(Style::default().fg(Color::Yellow))
            .alignment(Alignment::Left);

        frame.render_widget(temp, app_layout[1]);

        let cursor_pos = Position{
            x: input_inner_area.x + &self.line_input.cursor_pos.x,
            y: input_inner_area.y + &self.line_input.cursor_pos.y,
        };

        frame.set_cursor_position(cursor_pos);

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
            _ => {},
        };
    }

}
