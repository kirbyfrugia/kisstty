use std::{ cmp, sync::mpsc };

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent, KeyModifiers},
    layout::{ Alignment, Constraint, Direction, Layout, Position, Rect, Spacing, },
    style::{ Color, Modifier, Style, },
    widgets::{ Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap, },
    symbols::merge::MergeStrategy,
    Frame,
};

use crate::{
    ui::{LineInput,MultiLineOutput},
    event::Event,
    slash::SlashCommand,
    command::Command,
};

const MAX_INPUT_LEN: usize             = 80;
const TERMINAL_WIDTH: u16              = 80;
const SIDEBAR_WIDTH: u16               = 26;
const OUTPUT_AREA_WIDTH: u16           = TERMINAL_WIDTH + 4;
const SIDEBAR_AREA_WIDTH: u16          = SIDEBAR_WIDTH + 2;
const MIN_APP_WIDTH: u16               = OUTPUT_AREA_WIDTH + SIDEBAR_AREA_WIDTH;
const MAX_SLASH_POPUP_HEIGHT: u16      = 8;

#[derive(Debug)]
pub struct MainUi {
    terminal_input: LineInput,
    terminal_output: MultiLineOutput,
    event_sender: mpsc::Sender<Event>,
    slash_popup_list_state: ListState,
    counter: usize,
}

impl MainUi {
    pub fn new(event_sender: mpsc::Sender<Event>) -> Self {
        let li_event_sender = event_sender.clone();
        let terminal_input = LineInput::new(
            MAX_INPUT_LEN,
            TERMINAL_WIDTH.into(),
            li_event_sender,
        );

        let mlo_event_sender = event_sender.clone();
        let terminal_output = MultiLineOutput::new(
            mlo_event_sender,
        );

        Self {
            terminal_input,
            terminal_output,
            event_sender,
            slash_popup_list_state: ListState::default()
                .with_selected(Some(0)),
            counter: 0,
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
        let matching = SlashCommand::matching(&self.terminal_input.data);

        let num_matching: u16 = matching.len().try_into().unwrap();

        if num_matching == 0 { return }

        let popup_height: u16 = cmp::min(num_matching, MAX_SLASH_POPUP_HEIGHT);
        let mut popupy = inputy - (popup_height + 1);

        // if we have too many items in the popup, render a ...
        if popup_height < num_matching {
            let num_hidden = num_matching - popup_height;
            let ellipsis_str = format!("  ...{} more", num_hidden);

            popupy -= 1;
            let area = Rect {
                x: inputx,
                y: inputy - 2,
                width: OUTPUT_AREA_WIDTH - 3,
                height: 1
            };

            let ellipsis = Paragraph::new(ellipsis_str);
            frame.render_widget(ellipsis, area);
        }

        let area = Rect {
            x: inputx,
            y: popupy,
            width: OUTPUT_AREA_WIDTH - 3, // minus border and scroll
            height: popup_height,
        };
        frame.render_widget(Clear, area);

        let slash_width = SlashCommand::max_slash_width();

        let items: Vec<ListItem> = matching
            .iter()
            .map(|cmd| ListItem::new(format!("{:<slash_width$} {}", cmd.slash, cmd.friendly)))
            .collect();

        let list = List::new(items)
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
                Constraint::Length(OUTPUT_AREA_WIDTH), // left side with room
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

//        let terminal_output = Paragraph::new(format!("NOCALL>NOCALL:message"))
//            .block(
//                Block::default()
//                    .title("kisstty (net)")
//                    .title_alignment(Alignment::Left)
//                    .borders(Borders::ALL)
//                    .merge_borders(MergeStrategy::Exact),
//            )
//            .style(Style::default())
//            .alignment(Alignment::Left);
//
        let terminal_output_block = Block::bordered()
            .style(Style::default())
            .title("kisstty (net)")
            .title_alignment(Alignment::Left)
            .borders(Borders::ALL)
            .merge_borders(MergeStrategy::Exact);

        frame.render_widget(&terminal_output_block, terminal_layout[0]);

        let terminal_output_block_inner_area = terminal_output_block
            .inner(terminal_layout[0]);

        frame.render_widget(&self.terminal_output, terminal_output_block_inner_area);

//        frame.render_widget(terminal_output, terminal_layout[0]);

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
        frame.render_widget(&self.terminal_input, terminal_input_layout[1]);

        let terminal_input_area = terminal_input_layout[1];
        let cursor_pos = Position{
            x: terminal_input_area.x + self.terminal_input.screen_cursor as u16,
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

        let in_slash = self.terminal_input.is_typing_slash_command();

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

    pub fn tick(&mut self) {
        let new_line = format!("message #{}", self.counter);
        self.terminal_output.add_line(&new_line);
        self.counter += 1;
    }

    pub fn try_handle(&mut self, command: &Command) -> bool {
        match command {
            Command::UserKey(key_event) => self.handle_key(key_event),
            Command::Help => {
                self.print_help();
                true
            },
            _ => {
                self.terminal_input.try_handle(command) ||
                    self.terminal_output.try_handle(command)
            }
        }
    }

    pub fn handle_key(&mut self, key_event: &KeyEvent) -> bool {
        match key_event.code {
            KeyCode::Up => self.terminal_output.scroll_up(),
            KeyCode::Down => self.terminal_output.scroll_down(),
            KeyCode::Home if key_event.modifiers == KeyModifiers::CONTROL => self.terminal_output.scroll_to_top(),
            KeyCode::End if key_event.modifiers == KeyModifiers::CONTROL => self.terminal_output.scroll_to_bottom(),
            KeyCode::Left => self.terminal_input.move_cursor_left(),
            KeyCode::Right => self.terminal_input.move_cursor_right(),
            KeyCode::Delete => self.terminal_input.delete_char(),
            KeyCode::Backspace => self.terminal_input.backspace(),
            KeyCode::Tab => self.handle_tab(),
            KeyCode::Esc => self.terminal_output.toggle_view_mode(),
            KeyCode::Enter => self.handle_enter(),
            KeyCode::Char(c) => {
                self.terminal_input.insert_char(c);
            }
            _ => return false,
        }
        true
    }

    fn tab_complete(&mut self) {
        let matched = SlashCommand::matching(&self.terminal_input.data);

        if matched.len() == 0 { return }

        self.terminal_input.replace_data(matched.first().expect("wtf").slash);

    }

    fn handle_tab(&mut self) {
        let in_slash = self.terminal_input.is_typing_slash_command();
        if in_slash { self.tab_complete(); }
    }

    fn handle_enter(&mut self) {
        let input = self.terminal_input.data.clone();
        let (name, args) = input.split_once(' ').unwrap_or((input.as_str(), ""));

        if let Some(slash) = SlashCommand::find(name) {
            if let Some(command) = (slash.parse)(args) {
                let _ = self.event_sender.send(Event::SendCommand(command));
                self.terminal_input.replace_data("");
            }
        }
    }

    fn print_help(&mut self) {
        let help = String::from("help!");
        self.terminal_output.add_line(&help);
    }

}
