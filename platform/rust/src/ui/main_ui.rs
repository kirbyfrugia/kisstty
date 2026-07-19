use std::{ cmp, sync::mpsc };

use ratatui::{
    crossterm::event::{KeyCode, KeyEvent, KeyModifiers},
    layout::{ Alignment, Constraint, Direction, Layout, Position, Rect, Size, Spacing, },
    style::{ Color, Modifier, Style, },
    widgets::{ Block, BorderType, Borders, Clear, List, ListItem, ListState, Paragraph, },
    symbols::merge::MergeStrategy,
    Frame,
};

use crate::{
    kiss::AprsMessage,
    ui::{LineInput,MultiLineOutput,OutputUpdate},
    message::Message,
    slash::{SlashCommand, SLASH_COMMANDS},
};

const MAX_INPUT_LEN: usize             = 67;
const TERMINAL_WIDTH: u16              = 80;
const OUTPUT_AREA_WIDTH: u16           = TERMINAL_WIDTH + 4;
const MAX_SLASH_POPUP_HEIGHT: u16      = 8;
const INPUT_HEIGHT: u16                = 3;

#[derive(Debug)]
enum AppMode {
    Monitor,
    Net,
    Qso(String),
}

#[derive(Debug)]
pub struct MainUi {
    terminal_input: LineInput,
    terminal_output: MultiLineOutput,
    message_sender: mpsc::Sender<Message>,
    slash_popup_list_state: ListState,
    app_mode: AppMode,
}

impl MainUi {
    pub const MIN_SIZE: Size = Size {
        width: OUTPUT_AREA_WIDTH,
        height: INPUT_HEIGHT + MAX_SLASH_POPUP_HEIGHT + 3,
    };

    pub fn new(message_sender: mpsc::Sender<Message>) -> Self {
        let li_message_sender = message_sender.clone();
        let terminal_input = LineInput::new(
            MAX_INPUT_LEN,
            MAX_INPUT_LEN,
            li_message_sender,
        );

        let mlo_message_sender = message_sender.clone();
        let terminal_output = MultiLineOutput::new(
            mlo_message_sender,
        );

        Self {
            app_mode: AppMode::Net,
            terminal_input,
            terminal_output,
            message_sender,
            slash_popup_list_state: ListState::default()
                .with_selected(Some(0)),
        }
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

        let usage_width = SlashCommand::max_usage_width();

        let items: Vec<ListItem> = matching
            .iter()
            .map(|cmd| ListItem::new(format!("{:<usage_width$}  {}", cmd.usage(), cmd.friendly)))
            .collect();

        let list = List::new(items)
            .style(Color::White)
            .highlight_style(Modifier::REVERSED)
            .highlight_symbol("> ");

        frame.render_stateful_widget(list, area, &mut self.slash_popup_list_state);

    }

    pub fn render(&mut self, frame: &mut Frame) {
        let window_layout = Layout::default()
            .direction(Direction::Horizontal)
            .spacing(Spacing::Overlap(1))
            .constraints(vec![
                Constraint::Fill(1),
                Constraint::Length(Self::MIN_SIZE.width),
                Constraint::Fill(1),
            ])
            .split(frame.area());

        // layout for  the output and input area of the main app
        let terminal_layout = Layout::default()
            .direction(Direction::Vertical)
            .spacing(Spacing::Overlap(1))
            .constraints(vec![
                Constraint::Fill(1),   // output
                Constraint::Length(3), // input plus top/bottom border
            ])
            .split(window_layout[1]);

        let terminal_output_block = Block::bordered()
            .style(Style::default())
            .title(" kisstty ")
            .title_style(Style::default().add_modifier(Modifier::REVERSED))
            .title_alignment(Alignment::Center)
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .merge_borders(MergeStrategy::Fuzzy);

        frame.render_widget(&terminal_output_block, terminal_layout[0]);

        let terminal_output_block_inner_area = terminal_output_block
            .inner(terminal_layout[0]);

        frame.render_widget(&self.terminal_output, terminal_output_block_inner_area);

        let (mode, rx, tx) = match &self.app_mode {
            AppMode::Monitor => ("MONITOR", "all traffic", "broadcast"),
            AppMode::Net => ("NET", "messages", "broadcast"),
            AppMode::Qso(addressee) => ("QSO", addressee.as_str(), addressee.as_str()),
        };

        let app_mode_text = format!("{:<7} | RX: {:<11} | TX: {:<9}", mode, rx, tx);

        let terminal_input_block = Block::bordered()
            .title(format!(" {} ", app_mode_text))
            .title_style(Style::default().add_modifier(Modifier::REVERSED))
            .title_alignment(Alignment::Center)
            .style(Style::default())
            .border_type(BorderType::Rounded)
            .merge_borders(MergeStrategy::Fuzzy);

        frame.render_widget(&terminal_input_block, terminal_layout[1]);

        let terminal_input_block_inner_area = terminal_input_block
            .inner(terminal_layout[1]);

        let terminal_input_layout = Layout::default()
            .direction(Direction::Horizontal)
            .spacing(Spacing::Overlap(1))
            .constraints(vec![
                Constraint::Length(3),                     // prompt
                Constraint::Length(MAX_INPUT_LEN as u16 + 1), // input field (+1 spacer the divider overlaps)
                Constraint::Fill(1),                       // divider + char counter
            ])
            .split(terminal_input_block_inner_area);

        let terminal_input_prompt = Paragraph::new(format!("> "))
            .style(Style::default())
            .alignment(Alignment::Left);

        frame.render_widget(terminal_input_prompt, terminal_input_layout[0]);
        frame.render_widget(&self.terminal_input, terminal_input_layout[1]);

        let char_counter = Paragraph::new(format!(
            "│ {}/{}",
            self.terminal_input.data.len(),
            MAX_INPUT_LEN,
        ))
            .style(Style::default().fg(Color::DarkGray))
            .alignment(Alignment::Left);

        frame.render_widget(char_counter, terminal_input_layout[2]);

        let terminal_input_area = terminal_input_layout[1];
        let cursor_pos = Position{
            x: terminal_input_area.x + self.terminal_input.screen_cursor as u16,
            y: terminal_input_area.y,
        };
        frame.set_cursor_position(cursor_pos);

        let in_slash = self.terminal_input.is_typing_slash_command();

        if in_slash {
            self.render_slash_popup(
                frame, 
                terminal_input_block_inner_area.x,
                terminal_input_block_inner_area.y,
            );
        }

    }

    pub fn tick(&mut self) {
//        let new_line = format!("message #{}", self.counter);
//        self.terminal_output.add_line(&new_line);
//        self.counter += 1;
    }

    pub fn try_handle(&mut self, message: &Message) -> bool {
        match message {
            Message::UserKey(key_event) => self.handle_key(key_event),
            Message::Help => {
                self.print_help();
                true
            },
            Message::Monitor => {
                self.app_mode = AppMode::Monitor;
                true
            }
            Message::Net => {
                self.app_mode = AppMode::Net;
                true
            }
            Message::Qso(addressee) => {
                self.app_mode = AppMode::Qso(addressee.to_string());
                true
            }
            _ => {
                self.terminal_input.try_handle(message) ||
                    self.terminal_output.try_handle(message)
            }
        }
    }

    pub fn handle_key(&mut self, key_event: &KeyEvent) -> bool {
        match key_event.code {
            KeyCode::Up => self.terminal_output.scroll_up(),
            KeyCode::Down => self.terminal_output.scroll_down(),
            KeyCode::Home if key_event.modifiers == KeyModifiers::CONTROL => self.terminal_output.scroll_to_top(),
            KeyCode::End if key_event.modifiers == KeyModifiers::CONTROL => self.terminal_output.scroll_to_bottom(),
            KeyCode::Tab => self.handle_tab(),
            KeyCode::Esc => self.terminal_output.toggle_view_mode(),
            KeyCode::Enter => self.handle_enter(),
            KeyCode::Char('c') | KeyCode::Char('C') if key_event.modifiers == KeyModifiers::CONTROL => {
                self.clear_input();
            }
            _ => return self.terminal_input.handle_key(key_event),
        }
        true
    }

    fn tab_complete(&mut self) {
        let matched = SlashCommand::matching(&self.terminal_input.data);

        if matched.len() == 0 { return }

        let cmd = matched.first().expect("wtf");
        let completed = if cmd.args.is_empty() {
            cmd.slash.to_string()
        } else {
            format!("{} ", cmd.slash)
        };
        self.terminal_input.replace_data(&completed);
    }

    fn handle_tab(&mut self) {
        let in_slash = self.terminal_input.is_typing_slash_command();
        if in_slash { self.tab_complete(); }
    }

    fn handle_enter(&mut self) {
        let input = self.terminal_input.data.clone();
        if input.len() == 0 { return }
        let mut parts = input.split_whitespace();
        let name = parts.next().unwrap_or("");
        let args: Vec<&str> = parts.collect();

        if let Some(slash) = SlashCommand::find(name) {
            match (slash.to_message)(&args) {
                Some(message) => {
                    let _ = self.message_sender.send(message);
                    self.clear_input();
                }
                None => {
                    let mut lines: Vec<String> = Vec::new();
                    lines.push(format!("usage: {}", slash.usage()));
                    let output_update = OutputUpdate::new(lines);
                    let _ = self.message_sender.send(Message::Output(output_update));
                }
            }
        }
        else {
            if name.starts_with("/") {
                self.print_help();
                return
            }
            self.send_message(input);
            self.clear_input();
        }
    }

    fn clear_input(&mut self) {
        self.terminal_input.replace_data("");
    }

    fn print_help(&mut self) {
        let usage_width = SlashCommand::max_usage_width();

        let mut lines: Vec<String> = Vec::new();
        lines.push(String::from("Available commands:"));
        for cmd in SLASH_COMMANDS {
            lines.push(format!(
                "  {:<usage_width$}  {}",
                cmd.usage(),
                cmd.friendly,
            ));
        }
        lines.push(String::from(""));
        let output_update = OutputUpdate::new(lines);
        let _ = self.message_sender.send(Message::Output(output_update));
    }

    fn send_message(&mut self, text: String) {
        let addressee = match &self.app_mode {
            AppMode::Qso(addressee) => addressee.to_string(),
            _ => AprsMessage::BROADCAST_ADDRESSEE.to_string(),
        };

        let _ = self.message_sender.send(Message::SendAprsMessage { addressee, text });
    }

}
