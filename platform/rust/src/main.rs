mod app;
mod command;
mod event;
mod logging;
mod single_instance;
mod ui;
mod tui;

use app::App;
use color_eyre::Result;
use event::EventHandler;
use ratatui::{backend::CrosstermBackend, Terminal};
use tui::Tui;

fn main() -> Result<()> {
    // ensure only one instance runs on the machine
    let _instance = match single_instance::acquire()? {
        Some(guard) => guard,
        None => {
            eprintln!("kisstty is already running, exiting");
            std::process::exit(1);
        }
    };

    let _log_path = logging::init()?;
    tracing::info!("starting up kisstty");

    let mut app = App::new();

    let backend = CrosstermBackend::new(std::io::stderr());
    let terminal = Terminal::new(backend)?;
    let events = EventHandler::new(250);
    let mut tui = Tui::new(terminal, events);
    tui.enter()?;

    app.run(&mut tui)?;

    tui.exit()?;
    tracing::info!("shut down kisstty");
    Ok(())
}
