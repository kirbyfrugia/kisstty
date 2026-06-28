use std::path::PathBuf;

use color_eyre::Result;
use tracing_subscriber::{EnvFilter, fmt};

// to get debug logging:
//   RUST_LOG=debug cargo run
pub fn init() -> Result<PathBuf> {
    let log_path = PathBuf::from("kisstty.log");

    std::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&log_path)?;

    let file_appender = tracing_appender::rolling::never(".", &log_path);

    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    fmt()
        .with_writer(file_appender)
        .with_env_filter(filter)
        .with_ansi(false)
        .with_target(false)
        .init();

    Ok(log_path)
}
