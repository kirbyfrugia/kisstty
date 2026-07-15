mod config_ui;
mod line_input;
mod main_ui;
mod multi_line_output;
mod too_small_ui;

pub use config_ui::ConfigUi;
pub use line_input::LineInput;
pub use main_ui::MainUi;
pub use multi_line_output::MultiLineOutput;
pub use too_small_ui::TooSmallUi;

use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UiId(u64);

#[derive(Debug, Clone)]
pub struct OutputUpdate{
    #[allow(dead_code)]
    ui_id: UiId,
    lines: Vec<String>,
}

impl OutputUpdate {
    pub fn new(lines: Vec<String>) -> Self {
        Self {
            ui_id: next_id(),
            lines,
        }
    }
}

static NEXT_UI_ID: AtomicU64 = AtomicU64::new(1);

fn next_id() -> UiId{
    UiId(NEXT_UI_ID.fetch_add(1, Ordering::Relaxed))
}

