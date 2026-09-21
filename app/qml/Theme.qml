pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme
    // Read Omarchy's active generated palette. FileView watches for theme swaps.
    property color bg: "#1e1e2e"
    property color surface: "#181825"
    property color raised: "#313244"
    property color border: "#45475a"
    property color text: "#cdd6f4"
    property color muted: "#6c7086"
    property color accent: "#89b4fa"
    property color accentDark: "#45475a"
    property color danger: "#f38ba8"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    function value(source, key, fallback) {
        var lines = source.split("\n")
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].trim().indexOf(key + " = ") === 0) {
                var parts = lines[i].split("\"")
                return parts.length > 1 ? parts[1] : fallback
            }
        }
        return fallback
    }
    function applyOmarchyTheme(source) {
        bg = value(source, "background", bg)
        surface = value(source, "dark_background", bg)
        raised = value(source, "lighter_background", surface)
        border = value(source, "selection", raised)
        text = value(source, "foreground", text)
        muted = value(source, "dark_foreground", muted)
        accent = value(source, "accent", accent)
        accentDark = value(source, "selection", accentDark)
        danger = value(source, "red", danger)
    }

    property FileView themeFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
        watchChanges: true
        printErrors: false
        onLoaded: theme.applyOmarchyTheme(text())
        onFileChanged: reload()
    }
}
