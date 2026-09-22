#!/usr/bin/env bash
# Installs Omarchy Notepad for the current user. No sudo is required.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
config_base="${XDG_CONFIG_HOME:-$HOME/.config}"
release_id="$(sha256sum "$project_dir/app/shell.qml" "$project_dir/app/qtquickcontrols2.conf" "$project_dir/app/qml/"* | sha256sum | cut -c1-12)"
config_root="$config_base/omarchy-notepad-releases/$release_id"
config_link="$config_base/omarchy-notepad-current"
bin_root="${XDG_BIN_HOME:-$HOME/.local/bin}"
desktop_root="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

command -v quickshell >/dev/null || {
    echo "Quickshell is not installed. Install it first: sudo pacman -S quickshell"
    exit 1
}

install -d "$config_root" "$bin_root" "$desktop_root"
if [[ ! -f "$config_root/shell.qml" ]]; then
    cp "$project_dir/app/shell.qml" "$project_dir/app/qtquickcontrols2.conf" "$config_root/"
    cp -R "$project_dir/app/qml" "$config_root/qml"
fi
ln -sfn "$config_root" "$config_link"
install -m 755 "$project_dir/scripts/omarchy-notepad" "$bin_root/omarchy-notepad"

sed "s|@BIN@|$bin_root/omarchy-notepad|g" "$project_dir/assets/omarchy-notepad.desktop.in" > "$desktop_root/omarchy-notepad.desktop"
chmod 644 "$desktop_root/omarchy-notepad.desktop"

echo "Installed Omarchy Notepad ($release_id). New launches use this version; existing windows stay open."
