//! This app's own preferences (`~/.config/nexus-notepad/settings.toml`).

use crate::{cmd, paths};
use gtk::glib;
use serde::{Deserialize, Serialize};
use std::cell::{Cell, RefCell};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum ThemeMode {
    /// Follow the active Omarchy theme live.
    Omarchy,
    /// Use a bundled or custom theme.
    Theme,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct Prefs {
    pub mode: ThemeMode,
    pub theme: String,
    pub reduce_motion: bool,
    pub glow: bool,
    /// The editor's font family; empty for the app font (JetBrains Mono).
    pub font_family: String,
    /// The editor's font size, in points.
    pub font_size: f64,
    /// Line height as a multiple of the font size: 1.0, 1.2, 1.5 or 2.0.
    pub line_spacing: f64,
    /// Long lines wrap at the window edge (otherwise they scroll sideways).
    pub word_wrap: bool,
    /// Columns per tab stop.
    pub tab_width: u32,
    /// Tab types spaces up to the next tab stop.
    pub insert_spaces: bool,
    /// The text column's width: full, 80 or 100 characters, centred.
    pub text_width: String,
    pub line_numbers: bool,
    pub highlight_line: bool,
    /// Reopen saved files from last time (unsaved text always comes back).
    pub restore_tabs: bool,
    /// Line endings for new files: lf or crlf.
    pub line_ending: String,
    pub trim_trailing: bool,
    /// Show the tab strip even with one tab open.
    pub always_show_tabs: bool,
}

pub const DEFAULT_SIZE: f64 = 12.0;

impl Default for Prefs {
    fn default() -> Self {
        Self {
            mode: ThemeMode::Omarchy,
            theme: "tokyo-night".into(),
            reduce_motion: false,
            glow: true,
            font_family: String::new(),
            font_size: DEFAULT_SIZE,
            line_spacing: 1.2,
            word_wrap: true,
            tab_width: 4,
            insert_spaces: false,
            text_width: "full".into(),
            line_numbers: false,
            highlight_line: true,
            restore_tabs: true,
            line_ending: "lf".into(),
            trim_trailing: false,
            always_show_tabs: true,
        }
    }
}

thread_local! {
    static BROKEN: Cell<bool> = const { Cell::new(false) };
    static PREFS: RefCell<Prefs> = RefCell::new(load());
    static PENDING: Cell<Option<glib::SourceId>> = const { Cell::new(None) };
}

fn load() -> Prefs {
    let file = paths::prefs_file();
    let Ok(text) = std::fs::read_to_string(&file) else { return Prefs::default() };
    match toml::from_str(&text) {
        Ok(p) => p,
        Err(e) => {
            // Don't lose a file with a typo in it: keep a copy before the
            // defaults are saved over it.
            let backup = file.with_extension("toml.bak");
            let _ = std::fs::copy(&file, &backup);
            eprintln!("notepad: {} couldn't be read ({e}); kept a copy as {}", file.display(), backup.display());
            BROKEN.with(|b| b.set(true));
            Prefs::default()
        }
    }
}

/// True (once) when the settings file couldn't be read at start.
pub fn take_broken() -> bool {
    BROKEN.with(|b| b.replace(false))
}

pub fn get() -> Prefs {
    PREFS.with(|p| p.borrow().clone())
}

/// Change the prefs now; the file is written about 450 ms after the last change,
/// so dragging a slider doesn't rewrite it on every tick.
pub fn update(change: impl FnOnce(&mut Prefs)) {
    PREFS.with(|p| change(&mut p.borrow_mut()));
    if let Some(id) = PENDING.with(|p| p.take()) {
        id.remove();
    }
    let id = glib::timeout_add_local_once(std::time::Duration::from_millis(450), || {
        PENDING.with(|p| p.set(None));
        save();
    });
    PENDING.with(|p| p.set(Some(id)));
}

/// Write any pending change now (on quit).
pub fn flush() {
    if let Some(id) = PENDING.with(|p| p.take()) {
        id.remove();
        save();
    }
}

fn save() {
    let text = PREFS.with(|p| toml::to_string_pretty(&*p.borrow()));
    if let Ok(text) = text {
        let _ = cmd::atomic_write(&paths::prefs_file(), &text);
    }
}
