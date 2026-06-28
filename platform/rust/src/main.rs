mod app;
mod event;
mod logging;
mod single_instance;
mod ui;
mod tui;

use app::App;
use color_eyre::Result;
use event::{Event, EventHandler};
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

    while !app.should_quit {
        tui.draw(&mut app)?;
        match tui.events.next()? {
            Event::Tick => {}
            Event::Key(key_event) => app.handle_key(key_event),
            Event::Mouse(_) => {}
            Event::Resize(_,_) => {}
            Event::SendCommand(command) => app.handle_send_command(command),
        };
    }

    tui.exit()?;
    tracing::info!("shut down kisstty");
    Ok(())
}
