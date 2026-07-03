use crate::command::Command;

pub struct SlashCommand {
    pub slash:    &'static str,
    pub friendly: &'static str,
    pub parse:    fn(&str) -> Option<Command>,
}

pub const SLASH_COMMANDS: &[SlashCommand] = &[
    SlashCommand { slash: "/help",   friendly: "Show help",                        parse: |_| None },
    SlashCommand { slash: "/mycall", friendly: "Set your callsign",                parse: |_| None },
    SlashCommand { slash: "/net",    friendly: "Join or leave a net",              parse: |_| None },
    SlashCommand { slash: "/qso",    friendly: "Start a QSO",                      parse: |_| None },
    SlashCommand { slash: "/clear",  friendly: "Clear all the output",             parse: |_| Some(Command::Clear) },
    SlashCommand { slash: "/exit",   friendly: "Exit kisstty",                     parse: |_| Some(Command::Exit) },
    SlashCommand { slash: "/quit",   friendly: "Exit kisstty",                     parse: |_| Some(Command::Quit) },
    SlashCommand { slash: "/header", friendly: "Get header details for a message", parse: |_| None },
];

impl SlashCommand {
    pub fn matching(prefix: &str) -> Vec<&'static SlashCommand> {
        SLASH_COMMANDS
            .iter()
            .filter(|cmd| cmd.slash.starts_with(prefix))
            .collect()
    }

    pub fn find(name: &str) -> Option<&'static SlashCommand> {
        SLASH_COMMANDS
            .iter()
            .find(|cmd| cmd.slash == name)
    }

    pub fn max_slash_width() -> usize {
        SLASH_COMMANDS
            .iter()
            .map(|cmd| cmd.slash.len())
            .max()
            .unwrap_or(0)
    }
}
