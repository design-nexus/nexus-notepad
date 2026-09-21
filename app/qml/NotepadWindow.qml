pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.settings
import Quickshell
import Quickshell.Io
import "."

Window {
    id: app
    visible: true
    title: (dirty ? "● " : "") + (currentPath === "" ? "Untitled" : currentPath.split("/").pop()) + " — Omarchy Notepad"
    color: Theme.bg
    minimumWidth: 640
    minimumHeight: 420
    width: state.windowWidth
    height: state.windowHeight

    property string currentPath: ""
    property string savedText: ""
    property bool dirty: editor.text !== savedText
    property bool wrapEnabled: state.wrapEnabled
    property var recentFiles: []
    property string pendingAction: ""
    property string pendingAfterSave: ""
    property string requestedPath: ""
    property int findStart: 0
    property string transientMessage: "Ready"

    Settings {
        id: state
        category: "omarchy-notepad"
        fileName: Quickshell.statePath("preferences.ini")
        property int windowWidth: 1080
        property int windowHeight: 720
        property bool wrapEnabled: true
        property string recentFilesJson: "[]"
    }

    FileView {
        id: documentFile
        path: app.currentPath
        printErrors: false
        blockLoading: true
        onLoaded: {
            editor.text = text()
            app.savedText = editor.text
            editor.cursorPosition = 0
            app.transientMessage = "Opened " + app.basename(app.currentPath)
        }
        onLoadFailed: app.transientMessage = "Could not open file"
        onSaved: {
            app.savedText = editor.text
            app.rememberRecent(app.currentPath)
            app.transientMessage = "Saved " + app.basename(app.currentPath)
            if (app.pendingAfterSave !== "") {
                var next = app.pendingAfterSave
                app.pendingAfterSave = ""
                app.performAction(next)
            }
        }
        onSaveFailed: app.transientMessage = "Could not save file"
    }

    function basename(path) { return path === "" ? "Untitled" : path.split("/").pop() }
    function pathFromUrl(url) {
        var value = url.toString()
        if (value.indexOf("file://") === 0) value = value.substring(7)
        return decodeURIComponent(value)
    }
    function rememberRecent(path) {
        if (path === "") return
        var next = [path]
        for (var i = 0; i < recentFiles.length && next.length < 10; ++i)
            if (recentFiles[i] !== path) next.push(recentFiles[i])
        recentFiles = next
        state.recentFilesJson = JSON.stringify(next)
    }
    function requestAction(action) {
        if (dirty) { pendingAction = action; unsavedDialog.open() }
        else performAction(action)
    }
    function performAction(action) {
        if (action === "new") { currentPath = ""; editor.text = ""; savedText = ""; editor.forceActiveFocus() }
        else if (action === "open") openDialog.open()
        else if (action === "openPath") { currentPath = requestedPath; documentFile.reload(); requestedPath = "" }
        else if (action === "save") save()
        else if (action === "saveAs") saveDialog.open()
        else if (action === "close") Qt.quit()
    }
    function save() {
        if (currentPath === "") { saveDialog.open(); return }
        documentFile.setText(editor.text)
    }
    function saveThen(action) {
        pendingAfterSave = action
        if (currentPath === "") saveDialog.open()
        else documentFile.setText(editor.text)
    }
    function insertPair(left, right) {
        var selected = editor.selectedText
        if (selected.length > 0) editor.insert(editor.selectionStart, left + selected + right)
        else { editor.insert(editor.cursorPosition, left + right); editor.cursorPosition -= right.length }
        editor.forceActiveFocus()
    }
    function prefixLines(prefix, ordered) {
        var start = editor.selectionStart
        var end = editor.selectionEnd
        if (start === end) { start = editor.text.lastIndexOf("\n", start - 1) + 1; end = editor.text.indexOf("\n", end); if (end < 0) end = editor.text.length }
        var segment = editor.text.substring(start, end)
        var lines = segment.split("\n")
        for (var i = 0; i < lines.length; ++i) lines[i] = (ordered ? (i + 1) + ". " : prefix) + lines[i]
        editor.select(start, end); editor.insert(start, lines.join("\n")); editor.select(start, start + lines.join("\n").length)
        editor.forceActiveFocus()
    }
    function heading(level) {
        var start = editor.selectionStart
        if (editor.selectionStart === editor.selectionEnd) start = editor.text.lastIndexOf("\n", start - 1) + 1
        editor.insert(start, Array(level + 1).join("#") + " ")
        editor.forceActiveFocus()
    }
    function findNext() {
        if (findField.text.length === 0) return
        var at = editor.text.indexOf(findField.text, Math.max(editor.cursorPosition, findStart))
        if (at < 0) at = editor.text.indexOf(findField.text, 0)
        if (at >= 0) { editor.select(at, at + findField.text.length); findStart = at + findField.text.length; transientMessage = "Match found" }
        else transientMessage = "No match"
    }
    function replaceOne() {
        if (editor.selectedText === findField.text) { editor.insert(editor.selectionStart, replaceField.text); findStart = editor.cursorPosition }
        findNext()
    }
    function replaceAll() {
        if (findField.text.length === 0) return
        var count = editor.text.split(findField.text).length - 1
        editor.text = editor.text.split(findField.text).join(replaceField.text)
        transientMessage = count + " replacement" + (count === 1 ? "" : "s")
    }
    function lineColumn() {
        var before = editor.text.substring(0, editor.cursorPosition)
        var line = before.split("\n").length
        var column = before.length - before.lastIndexOf("\n")
        return "Ln " + line + ", Col " + column
    }

    Component.onCompleted: {
        try { recentFiles = JSON.parse(state.recentFilesJson) } catch (e) { recentFiles = [] }
        editor.forceActiveFocus()
    }
    onWidthChanged: if (width >= minimumWidth) state.windowWidth = width
    onHeightChanged: if (height >= minimumHeight) state.windowHeight = height
    onClosing: function(close) { if (dirty) { close.accepted = false; pendingAction = "close"; unsavedDialog.open() } }

    FileDialog {
        id: openDialog
        title: "Open a note"
        nameFilters: ["Notes (*.md *.txt)", "All files (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: { app.currentPath = app.pathFromUrl(selectedFile); documentFile.reload(); app.rememberRecent(app.currentPath) }
    }
    FileDialog {
        id: saveDialog
        title: "Save note as"
        nameFilters: ["Markdown (*.md)", "Text (*.txt)"]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "md"
        onAccepted: { app.currentPath = app.pathFromUrl(selectedFile); app.save() }
        onRejected: app.pendingAfterSave = ""
    }
    Dialog {
        id: unsavedDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Save changes?"
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        contentItem: Label { text: "Your changes to “" + app.basename(app.currentPath) + "” haven’t been saved."; color: Theme.text; padding: 18; wrapMode: Text.WordWrap }
        onAccepted: { var next = app.pendingAction; app.pendingAction = ""; app.saveThen(next) }
        onDiscarded: { var next = app.pendingAction; app.pendingAction = ""; app.savedText = editor.text; app.performAction(next) }
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: app.requestAction("new") }
    Shortcut { sequence: "Ctrl+O"; onActivated: app.requestAction("open") }
    Shortcut { sequence: "Ctrl+S"; onActivated: app.save() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: saveDialog.open() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { findBar.visible = true; findField.forceActiveFocus(); findField.selectAll() } }
    Shortcut { sequence: "Ctrl+H"; onActivated: { findBar.visible = true; replaceField.visible = true; findField.forceActiveFocus() } }
    Shortcut { sequence: "Escape"; onActivated: { if (findBar.visible) { findBar.visible = false; editor.forceActiveFocus() } } }
    Shortcut { sequence: "Ctrl+B"; onActivated: app.insertPair("**", "**") }
    Shortcut { sequence: "Ctrl+I"; onActivated: app.insertPair("*", "*") }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 48; color: Theme.surface
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 10
                Label { text: "NOTEPAD"; color: Theme.accent; font.family: Theme.fontFamily; font.bold: true; font.pixelSize: 15 }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 18; color: Theme.border; Layout.leftMargin: 12; Layout.rightMargin: 12 }
                Label { text: app.basename(app.currentPath); color: Theme.muted; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Item { Layout.fillWidth: true }
                ToolButton {
                    id: menuButton
                    text: "☰"
                    font.pixelSize: 20
                    onClicked: appMenu.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "Menu"
                }
            }
            Popup {
                id: appMenu
                parent: Overlay.overlay
                x: app.width - width - 12
                y: 54
                width: 290
                height: Math.min(560, menuContent.implicitHeight + topPadding + bottomPadding)
                padding: 8
                clip: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle { color: Theme.surface; border.color: Theme.border; border.width: 1; radius: 8 }
                contentItem: Flickable {
                    id: menuFlickable
                    contentWidth: width
                    contentHeight: menuContent.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: menuContent.implicitHeight > appMenu.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                    ColumnLayout {
                        id: menuContent
                        width: menuFlickable.width
                        spacing: 2
                        Label { text: "FILE"; color: Theme.muted; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 4 }
                        ThemedMenuButton { text: "New    Ctrl+N"; onClicked: { app.requestAction("new"); appMenu.close() } }
                        ThemedMenuButton { text: "Open…    Ctrl+O"; onClicked: { app.requestAction("open"); appMenu.close() } }
                        ThemedMenuButton { text: "Save    Ctrl+S"; enabled: app.dirty; onClicked: { app.save(); appMenu.close() } }
                        ThemedMenuButton { text: "Save As…    Ctrl+Shift+S"; onClicked: { saveDialog.open(); appMenu.close() } }
                        Label { text: "EDIT"; color: Theme.muted; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 12 }
                        ThemedMenuButton { text: "Undo    Ctrl+Z"; enabled: editor.canUndo; onClicked: { editor.undo(); appMenu.close() } }
                        ThemedMenuButton { text: "Redo    Ctrl+Shift+Z"; enabled: editor.canRedo; onClicked: { editor.redo(); appMenu.close() } }
                        ThemedMenuButton { text: "Find…    Ctrl+F"; onClicked: { findBar.visible = true; findField.forceActiveFocus(); findField.selectAll(); appMenu.close() } }
                        ThemedMenuButton { text: "Find and Replace…    Ctrl+H"; onClicked: { findBar.visible = true; replaceField.visible = true; findField.forceActiveFocus(); appMenu.close() } }
                        Label { text: "MARKDOWN"; color: Theme.muted; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 12 }
                        ThemedMenuButton { text: "Bold    Ctrl+B"; onClicked: { app.insertPair("**", "**"); appMenu.close() } }
                        ThemedMenuButton { text: "Italic    Ctrl+I"; onClicked: { app.insertPair("*", "*"); appMenu.close() } }
                        ThemedMenuButton { text: "Heading 1"; onClicked: { app.heading(1); appMenu.close() } }
                        ThemedMenuButton { text: "Heading 2"; onClicked: { app.heading(2); appMenu.close() } }
                        ThemedMenuButton { text: "Bullet List"; onClicked: { app.prefixLines("- ", false); appMenu.close() } }
                        ThemedMenuButton { text: "Numbered List"; onClicked: { app.prefixLines("", true); appMenu.close() } }
                        ThemedMenuButton { text: "Inline Code"; onClicked: { app.insertPair("`", "`"); appMenu.close() } }
                        ThemedMenuButton { text: "Link"; onClicked: { app.insertPair("[", "](https://)"); appMenu.close() } }
                        Label { text: "VIEW"; color: Theme.muted; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 12 }
                        ThemedMenuButton { text: app.wrapEnabled ? "✓  Word Wrap" : "Word Wrap"; onClicked: { app.wrapEnabled = !app.wrapEnabled; state.wrapEnabled = app.wrapEnabled } }
                        Label { text: "RECENT FILES"; color: Theme.muted; visible: app.recentFiles.length > 0; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 12 }
                        Repeater {
                            model: app.recentFiles
                            delegate: ThemedMenuButton {
                                required property string modelData
                                text: app.basename(modelData)
                                onClicked: { app.requestedPath = modelData; app.requestAction("openPath"); appMenu.close() }
                            }
                        }
                        ThemedMenuButton { text: "Clear recent files"; visible: app.recentFiles.length > 0; onClicked: { app.recentFiles = []; state.recentFilesJson = "[]" } }
                    }
                }
            }
        }
        Rectangle {
            id: findBar; visible: false; Layout.fillWidth: true; Layout.preferredHeight: visible ? 48 : 0; color: Theme.surface; clip: true
            RowLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 8
                TextField { id: findField; Layout.preferredWidth: 220; placeholderText: "Find"; onAccepted: app.findNext() }
                TextField { id: replaceField; Layout.preferredWidth: 220; visible: false; placeholderText: "Replace with"; onAccepted: app.replaceOne() }
                Button { text: "Next"; onClicked: app.findNext() }
                Button { text: "Replace"; visible: replaceField.visible; onClicked: app.replaceOne() }
                Button { text: "All"; visible: replaceField.visible; onClicked: app.replaceAll() }
                Item { Layout.fillWidth: true }
                ToolButton { text: "×"; onClicked: { findBar.visible = false; editor.forceActiveFocus() } }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.bg
            ScrollView {
                anchors.fill: parent; anchors.margins: 18; clip: true
                TextArea {
                    id: editor
                    wrapMode: app.wrapEnabled ? TextEdit.Wrap : TextEdit.NoWrap
                    selectByMouse: true
                    persistentSelection: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    color: Theme.text
                    selectionColor: Theme.accentDark
                    selectedTextColor: Theme.text
                    background: Rectangle { color: "transparent" }
                    placeholderText: "Start writing…\n\nMarkdown shortcuts: Ctrl+B bold · Ctrl+I italic · Ctrl+F find"
                    placeholderTextColor: Theme.muted
                    onCursorPositionChanged: app.transientMessage = "Ready"
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 28; color: Theme.surface
            RowLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                Label { text: app.currentPath === "" ? "Unsaved note" : app.currentPath; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.fillWidth: true }
                Label { text: app.dirty ? "Modified" : app.transientMessage; color: app.dirty ? Theme.accent : Theme.muted; font.pixelSize: 11 }
                Label { text: app.lineColumn(); color: Theme.muted; font.pixelSize: 11; Layout.leftMargin: 16 }
                Label { text: editor.text.length + " chars"; color: Theme.muted; font.pixelSize: 11; Layout.leftMargin: 12 }
            }
        }
    }
}
