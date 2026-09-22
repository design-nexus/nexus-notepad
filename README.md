# Omarchy Notepad

Omarchy Notepad is a small, dark, keyboard-first editor written entirely in QML for Quickshell. It stores ordinary Markdown (`.md`) or plain-text (`.txt`) files—there is no rich-text format or backend service.

## What it includes

- Multiple document tabs, with independent edits, undo history, and unsaved-change confirmation when closing a tab or the window
- New, Open, Save, Save As, and recent files
- A compact tab strip with a new-tab button and organized hamburger menu for file, edit, view, recent-file, and Markdown actions
- Markdown actions for bold, italic, H1/H2 headings, bullets, numbered lists, inline code, and links
- Undo/redo, system cut/copy/paste/select-all, Find/Replace, word wrap, and a live line/column status bar
- Persistent window dimensions, word-wrap choice, and ten recent files
- Native file dialogs restricted to `.md` and `.txt` by default
- Automatic active-Omarchy-theme colors, including live updates after a theme change

## Requirements

Omarchy already ships Quickshell on most installations. Verify it with:

```bash
quickshell --version
```

If needed, install the dependency on Arch/Omarchy:

```bash
sudo pacman -S quickshell
```

The project targets Quickshell 0.3+ and Qt 6. It uses only standard Qt Quick modules and Quickshell's `FileView`, so Rust, Node, and a build step are not required.

## Install

From this project directory:

```bash
chmod +x scripts/install.sh scripts/omarchy-notepad
./scripts/install.sh
```

The installer copies each version to `~/.config/omarchy-notepad-releases`, points `~/.config/omarchy-notepad-current` at the latest version, adds `omarchy-notepad` to `~/.local/bin`, and creates an application-launcher entry. Existing windows keep their original version and open notes when you update; new launches use the latest version. Each launch opens an independent window. Ensure `~/.local/bin` is on your `PATH` (Omarchy normally configures this already).

## Run without installing

```bash
quickshell --path ./app
```

Run this inside your active Omarchy/Wayland session. A headless terminal cannot display the Qt window, but QML syntax can still be checked as described below.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+N` or `Ctrl+T`, `Ctrl+O`, `Ctrl+S`, `Ctrl+Shift+S` | New tab, Open, Save, Save As |
| `Ctrl+W`, `Ctrl+Tab` | Close tab, next tab |
| `Ctrl+Z`, `Ctrl+Shift+Z` | Undo, Redo |
| `Ctrl+X`, `Ctrl+C`, `Ctrl+V`, `Ctrl+A` | Cut, Copy, Paste, Select all |
| `Ctrl+F`, `Ctrl+H`, `Esc` | Find, Find/replace, close search |
| `Ctrl+B`, `Ctrl+I` | Markdown bold, italic |

Qt's `TextArea` supplies the standard editing shortcuts. The hamburger menu exposes every Markdown action.
Middle-clicking a tab closes it; modified tabs still ask whether to save changes.

## Validate

On an Arch system with Qt declarative tools installed:

```bash
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml app/shell.qml app/qml/*.qml
```

## Notes

Each launch creates an independent window. It never modifies Omarchy's own configuration or files under `/usr/share/omarchy`; it runs as a separate Quickshell configuration. Preferences are saved through Qt's per-user settings store.
