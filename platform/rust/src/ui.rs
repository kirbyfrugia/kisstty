use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Spacing},
    style::{Color, Style},
    widgets::{Block, BorderType, Borders, Paragraph},
    symbols::merge::MergeStrategy,
    Frame,
};

use crate::app::App;

pub fn render(app: &mut App, frame: &mut Frame) {
    let main_outer_layout = Layout::default()
        .direction(Direction::Horizontal)
        .spacing(Spacing::Overlap(1))
        .constraints(vec![
            Constraint::Fill(1),
            Constraint::Length(123),
            Constraint::Fill(1),
        ])
        .split(frame.area());

    let outer_layout = Layout::default()
        .direction(Direction::Horizontal)
        .spacing(Spacing::Overlap(1))
        .constraints(vec![
            Constraint::Length(82), // left side
            Constraint::Length(41), // right side
        ])
        .split(main_outer_layout[1]);

    let output_input_layout = Layout::default()
        .direction(Direction::Vertical)
        .spacing(Spacing::Overlap(1))
        .constraints(vec![
            Constraint::Fill(1),   // output
            Constraint::Length(3), // input
        ])
        .split(outer_layout[0]);

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


    frame.render_widget(output, output_input_layout[0]);

    let input = Block::bordered()
        .style(Style::default().fg(Color::Yellow))
        .merge_borders(MergeStrategy::Exact);

    frame.render_widget(input, output_input_layout[1]);

    let temp = Paragraph::new("01234567890123456789012345678901234567890123456789012345678901234567890123456789")
        .block(
            Block::default()
                .title("blah")
                .title_alignment(Alignment::Left)
                .borders(Borders::ALL)
                .merge_borders(MergeStrategy::Exact),
        )
        .style(Style::default().fg(Color::Yellow))
        .alignment(Alignment::Left);

    frame.render_widget(temp, outer_layout[1]);

}
