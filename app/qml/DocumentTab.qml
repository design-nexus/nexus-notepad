import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "."

Item {
    id: document
    anchors.fill: parent
    visible: false

    property string path: ""
    property string savedText: ""
    property string writeSnapshot: ""
    property string status: "Ready"
    property bool wrapEnabled: true
    readonly property bool dirty: editor.text !== savedText
    readonly property string text: editor.text
    readonly property int cursorPosition: editor.cursorPosition
    readonly property string selectedText: editor.selectedText
    readonly property int selectionStart: editor.selectionStart
    readonly property int selectionEnd: editor.selectionEnd
    readonly property bool canUndo: editor.canUndo
    readonly property bool canRedo: editor.canRedo

    signal saved()
    signal saveFailed()
    signal loaded()
    signal loadFailed()

    function basename() { return path === "" ? "Untitled" : path.split("/").pop() }
    function focusEditor() { editor.forceActiveFocus() }
    function newContent() { editor.text = ""; savedText = ""; path = ""; status = "Ready" }
    function openFile(filePath) { path = filePath; file.reload() }
    function saveFile() { writeSnapshot = editor.text; file.setText(writeSnapshot) }
    function saveFileAs(filePath) { path = filePath; saveFile() }
    function undo() { editor.undo() }
    function redo() { editor.redo() }
    function cut() { editor.cut() }
    function copy() { editor.copy() }
    function paste() { editor.paste() }
    function selectAll() { editor.selectAll() }
    function insert(position, value) { editor.insert(position, value) }
    function select(start, end) { editor.select(start, end) }
    function setCursor(position) { editor.cursorPosition = position }
    function replaceText(value) { editor.text = value }

    function lineColumn() {
        var before = editor.text.substring(0, editor.cursorPosition)
        var line = before.split("\n").length
        return "Ln " + line + ", Col " + (before.length - before.lastIndexOf("\n"))
    }

    FileView {
        id: file
        path: document.path
        preload: false
        printErrors: false
        blockLoading: true
        onLoaded: {
            editor.text = text()
            document.savedText = editor.text
            editor.cursorPosition = 0
            document.status = "Opened " + document.basename()
            document.loaded()
        }
        onLoadFailed: { document.status = "Could not open file"; document.loadFailed() }
        onSaved: {
            document.savedText = document.writeSnapshot
            document.status = "Saved " + document.basename()
            document.saved()
        }
        onSaveFailed: { document.status = "Could not save file"; document.saveFailed() }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        TextArea {
            id: editor
            wrapMode: document.wrapEnabled ? TextEdit.Wrap : TextEdit.NoWrap
            selectByMouse: true
            persistentSelection: true
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: Theme.text
            selectionColor: Theme.accentDark
            selectedTextColor: Theme.text
            background: Rectangle { color: "transparent" }
            placeholderText: "Start writing…"
            placeholderTextColor: Theme.muted
        }
    }
}
