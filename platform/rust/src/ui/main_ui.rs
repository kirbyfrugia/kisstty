use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Spacing},
    style::{Color, Style},
    widgets::{Block, Borders, Paragraph, Wrap},
    symbols::merge::MergeStrategy,
    Frame,
};

use crate:: {
    app::App,
    ui::LineInput,
};

const TERMINAL_WIDTH: u16 = 80;
const SIDEBAR_WIDTH:  u16 = 26;
const MIN_APP_WIDTH:  u16 = (TERMINAL_WIDTH + 2) + (SIDEBAR_WIDTH + 2);

pub struct MainUi {
    line_input: LineInput,
}

impl MainUi {
    pub fn new() -> Self {
        Self {
            line_input: LineInput::new(),
        }
    }
    fn render_too_small(&mut self, _app: &mut App, frame: &mut Frame) {
        let warning = Paragraph::new("Make the window wider")
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

    fn render_full_ui(&mut self, app: &mut App, frame: &mut Frame) {
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

        let output = Paragraph::new(format!("{}", app.counter))
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


        //line_input.render(input.area(), 


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

    }

    pub fn render(&mut self, app: &mut App, frame: &mut Frame) {
    //    tracing::info!(min_width, frame_width=frame.area().width, "width");
        if frame.area().width < MIN_APP_WIDTH {
            self.render_too_small(app, frame);
        } else {
            self.render_full_ui(app, frame);
        }
    }
}
