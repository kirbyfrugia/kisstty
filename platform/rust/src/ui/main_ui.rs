use std::{ cmp, sync::mpsc };

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent},
    layout::{ Alignment, Constraint, Direction, Layout, Position, Rect, Spacing, },
    style::{ Color, Modifier, Style, },
    widgets::{ Block, Borders, Clear, List, ListState, Paragraph, Wrap, },
    symbols::merge::MergeStrategy,
    Frame,
};

use crate::{ ui::LineInput, event::Event };

const MAX_INPUT_LEN: usize             = 80;
const TERMINAL_WIDTH: u16              = 80;
const SIDEBAR_WIDTH: u16               = 26;
const MIN_APP_WIDTH: u16               = (TERMINAL_WIDTH + 4) + (SIDEBAR_WIDTH + 2);
const MAX_SLASH_POPUP_HEIGHT: u16      = 8;
const SLASH_COMMANDS_COMMON: [&str; 6] = [
    "/help",
    "/mycall",
    "/net",
    "/qso",
    "/exit",
    "/quit",
];

#[derive(Debug)]
pub struct MainUi {
    line_input: LineInput,
    event_sender: mpsc::Sender<Event>,
    slash_popup_list_state: ListState,
}

impl MainUi {
    pub fn new(event_sender: mpsc::Sender<Event>) -> Self {
        let li_event_sender = event_sender.clone();
        let line_input = LineInput::new(
            MAX_INPUT_LEN,
            TERMINAL_WIDTH.into(),
            li_event_sender,
        );

        Self {
            line_input,
            event_sender,
            slash_popup_list_state: ListState::default()
                .with_selected(Some(0)),
        }
    }

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

        let popup_height: u16 = cmp::min(num_matching, MAX_SLASH_POPUP_HEIGHT);
        let mut popupy = inputy - (popup_height + 1);
        let mut popup_width: u16 = max_len;

        // if we have too many items in the popup, render a ...
        if popup_height < num_matching {
            let num_hidden = num_matching - popup_height;
            let ellipsis_str = format!("  ...{} more", num_hidden);

            popup_width = cmp::max(max_len, (ellipsis_str.len()+1).try_into().unwrap());

            popupy -= 1;
            let area = Rect {
                x: inputx,
                y: inputy - 2,
                width: popup_width,
                height: 1
            };

            let ellipsis = Paragraph::new(ellipsis_str);
            frame.render_widget(ellipsis, area);
        }

        let area = Rect {
            x: inputx,
            y: popupy,
            width: popup_width,
            height: popup_height,
        };
        frame.render_widget(Clear, area);

        let list = List::new(matching)
            .style(Color::White)
            .highlight_style(Modifier::REVERSED)
            .highlight_symbol("> ");

        frame.render_stateful_widget(list, area, &mut self.slash_popup_list_state);

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

        // layout for  the output and input area of the main app
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

        let terminal_input_block_inner_area = terminal_input_block
            .inner(terminal_layout[1]);

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

        let in_slash = self.line_input.is_typing_slash_command();

        if in_slash {
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
            KeyCode::Tab => self.handle_tab(),
            KeyCode::Enter => self.handle_enter(),
            KeyCode::Char(c) => {
                self.line_input.insert_char(c);
            }
            _ => { },

        };
    }

    fn tab_complete(&mut self) {
        let matched: Vec<_> = SLASH_COMMANDS_COMMON
            .into_iter()
            .filter(|cmd_str| cmd_str.starts_with(&self.line_input.data))
            .collect();

        if matched.len() == 0 { return }

        self.line_input.replace_data(matched.first().expect("wtf"));

    }

    fn handle_tab(&mut self) {
        let in_slash = self.line_input.is_typing_slash_command();
        if in_slash { self.tab_complete(); }
    }

    fn handle_enter(&mut self) {
        match self.line_input.data.as_str() {
            "/exit"|"/quit" => {
                let _ = self.event_sender.send(Event::Quit);
            },
            _ => {}
        }
    }

}
