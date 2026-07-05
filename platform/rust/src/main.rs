mod app;
mod config;
mod event;
mod kiss;
mod logging;
mod message;
mod single_instance;
mod slash;
mod ui;

use app::App;
use color_eyre::Result;

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

    App::new().run()?;

    tracing::info!("shut down kisstty");
    Ok(())
}
