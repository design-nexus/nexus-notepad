#!/usr/bin/env bash
# Installs Notepad for the current user. No sudo is required.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
config_base="${XDG_CONFIG_HOME:-$HOME/.config}"
release_id="$(sha256sum "$project_dir/app/shell.qml" "$project_dir/app/qtquickcontrols2.conf" "$project_dir/app/qml/"* | sha256sum | cut -c1-12)"
config_root="$config_base/nexus-notepad-releases/$release_id"
config_link="$config_base/nexus-notepad-current"
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
install -m 755 "$project_dir/scripts/nexus-notepad" "$bin_root/nexus-notepad"
install -m 755 "$project_dir/scripts/omarchy-notepad" "$bin_root/omarchy-notepad"

sed "s|@BIN@|$bin_root/nexus-notepad|g" "$project_dir/assets/nexus-notepad.desktop.in" > "$desktop_root/nexus-notepad.desktop"
chmod 644 "$desktop_root/nexus-notepad.desktop"
legacy_desktop="$desktop_root/omarchy-notepad.desktop"
if [[ -f "$legacy_desktop" ]] && grep -q '^Name=Omarchy Notepad$' "$legacy_desktop"; then
    mv "$legacy_desktop" "$desktop_root/omarchy-notepad.desktop.disabled"
fi

echo "Installed Notepad ($release_id). Launch with nexus-notepad; existing windows stay open."
