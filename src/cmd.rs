//! Running external commands and writing files safely.

use anyhow::{Context, Result};
use std::path::Path;
use std::process::{Command, Stdio};

pub fn present(program: &str) -> bool {
    if program.contains('/') {
        return Path::new(program).exists();
    }
    std::env::var_os("PATH").map(|paths| std::env::split_paths(&paths).any(|dir| dir.join(program).is_file())).unwrap_or(false)
}

/// Fire and forget. The child is reaped on a helper thread so no zombies remain.
pub fn spawn(args: &[&str]) {
    let args: Vec<String> = args.iter().map(|s| s.to_string()).collect();
    std::thread::spawn(move || {
        if let Some((program, rest)) = args.split_first() {
            let _ = Command::new(program).args(rest).stdin(Stdio::null()).status();
        }
    });
}

/// Open a file in the user's default editor (Omarchy's choice), falling back to xdg-open.
pub fn open_in_editor(path: &Path) {
    if !path.exists() {
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = std::fs::write(path, "");
    }
    let p = path.to_string_lossy().to_string();
    if present("omarchy-launch-editor") {
        spawn(&["omarchy-launch-editor", &p]);
    } else {
        spawn(&["xdg-open", &p]);
    }
}

/// Write a file atomically: a temp file in the same directory, then rename. A file
/// that's already there keeps its permissions, and a symlink keeps pointing at it.
pub fn atomic_write(path: &Path, contents: impl AsRef<[u8]>) -> Result<()> {
    let path = std::fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let dir = path.parent().context("path has no parent")?;
    std::fs::create_dir_all(dir)?;
    let tmp = dir.join(format!(".{}.tmp-{}", path.file_name().unwrap_or_default().to_string_lossy(), std::process::id()));
    std::fs::write(&tmp, contents).with_context(|| format!("could not write {}", path.display()))?;
    if let Ok(meta) = std::fs::metadata(&path) {
        let _ = std::fs::set_permissions(&tmp, meta.permissions());
    }
    if let Err(e) = std::fs::rename(&tmp, &path) {
        let _ = std::fs::remove_file(&tmp);
        return Err(e).with_context(|| format!("could not write {}", path.display()));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn atomic_write_keeps_permissions_and_symlinks() {
        let dir = std::env::temp_dir().join(format!("notepad-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let file = dir.join("a.sh");
        std::fs::write(&file, "old").unwrap();
        std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o750)).unwrap();
        let link = dir.join("link");
        let _ = std::fs::remove_file(&link);
        std::os::unix::fs::symlink(&file, &link).unwrap();

        atomic_write(&link, "new").unwrap();
        assert_eq!(std::fs::read_to_string(&file).unwrap(), "new");
        assert!(std::fs::symlink_metadata(&link).unwrap().file_type().is_symlink());
        assert_eq!(std::fs::metadata(&file).unwrap().permissions().mode() & 0o777, 0o750);
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
