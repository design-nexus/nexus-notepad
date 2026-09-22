pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.settings
import Quickshell
import "."

Window {
    id: app
    visible: true
    title: (activeTab && activeTab.dirty ? "● " : "") + (activeTab ? activeTab.basename() : "Untitled") + " — Omarchy Notepad"
    color: Theme.bg
    minimumWidth: 640
    minimumHeight: 420
    width: state.windowWidth
    height: state.windowHeight

    property var tabs: []
    property var activeTab: null
    property bool wrapEnabled: state.wrapEnabled
    property var recentFiles: []
    property string pendingAction: ""
    property var pendingTab: null
    property var saveTarget: null
    property bool closingAll: false
    property bool allowClose: false
    property int findStart: 0

    Settings {
        id: state
        category: "omarchy-notepad"
        fileName: Quickshell.statePath("preferences.ini")
        property int windowWidth: 1080
        property int windowHeight: 720
        property bool wrapEnabled: true
        property string recentFilesJson: "[]"
    }

    Component { id: documentComponent; DocumentTab { } }

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
    function addTab(path) {
        var tab = documentComponent.createObject(documentHost, { "wrapEnabled": Qt.binding(function() { return app.wrapEnabled }) })
        if (!tab) return null
        tab.saved.connect(function() {
            app.rememberRecent(tab.path)
            if (app.pendingTab === tab) {
                if (tab.dirty) unsavedDialog.open()
                else app.finishPending()
            }
        })
        tab.saveFailed.connect(function() { if (app.pendingTab === tab) { app.pendingAction = ""; app.pendingTab = null; app.closingAll = false } })
        tabs = tabs.concat([tab])
        switchTab(tab)
        if (path) tab.openFile(path)
        return tab
    }
    function switchTab(tab) {
        if (!tab || activeTab === tab) return
        if (activeTab) activeTab.visible = false
        activeTab = tab
        tab.visible = true
        findStart = 0
        tab.focusEditor()
    }
    function openPath(path) {
        for (var i = 0; i < tabs.length; ++i) {
            if (tabs[i].path === path) { switchTab(tabs[i]); return }
        }
        addTab(path)
    }
    function closeTab(tab) {
        if (!tab) return
        if (tab.dirty) { pendingTab = tab; pendingAction = "closeTab"; unsavedDialog.open(); return }
        removeTab(tab)
    }
    function removeTab(tab) {
        var index = tabs.indexOf(tab)
        if (index < 0) return
        var next = tabs.slice()
        next.splice(index, 1)
        tabs = next
        if (activeTab === tab) {
            activeTab = null
            if (next.length) switchTab(next[Math.min(index, next.length - 1)])
        }
        tab.destroy()
        if (!next.length && !closingAll) addTab("")
    }
    function requestCloseAll() {
        for (var i = 0; i < tabs.length; ++i) {
            if (tabs[i].dirty) {
                closingAll = true
                pendingTab = tabs[i]
                pendingAction = "closeAll"
                switchTab(pendingTab)
                unsavedDialog.open()
                return
            }
        }
        allowClose = true
        Qt.quit()
    }
    function finishPending() {
        var action = pendingAction
        var tab = pendingTab
        pendingAction = ""
        pendingTab = null
        if (action === "closeTab") removeTab(tab)
        else if (action === "closeAll") requestCloseAll()
    }
    function save(tab) {
        if (!tab) return
        if (tab.path === "") { saveTarget = tab; saveDialog.open() }
        else tab.saveFile()
    }
    function saveAs(tab) { if (tab) { saveTarget = tab; saveDialog.open() } }
    function insertPair(left, right) {
        var tab = activeTab
        if (!tab) return
        var selected = tab.selectedText
        if (selected.length > 0) tab.insert(tab.selectionStart, left + selected + right)
        else { var cursor = tab.cursorPosition; tab.insert(cursor, left + right); tab.setCursor(cursor + left.length) }
        tab.focusEditor()
    }
    function prefixLines(prefix, ordered) {
        var tab = activeTab
        if (!tab) return
        var start = tab.selectionStart
        var end = tab.selectionEnd
        if (start === end) { start = tab.text.lastIndexOf("\n", start - 1) + 1; end = tab.text.indexOf("\n", end); if (end < 0) end = tab.text.length }
        var segment = tab.text.substring(start, end)
        var lines = segment.split("\n")
        for (var i = 0; i < lines.length; ++i) lines[i] = (ordered ? (i + 1) + ". " : prefix) + lines[i]
        var replacement = lines.join("\n")
        tab.select(start, end); tab.insert(start, replacement); tab.select(start, start + replacement.length)
        tab.focusEditor()
    }
    function heading(level) {
        var tab = activeTab
        if (!tab) return
        var start = tab.selectionStart
        if (tab.selectionStart === tab.selectionEnd) start = tab.text.lastIndexOf("\n", start - 1) + 1
        tab.insert(start, Array(level + 1).join("#") + " ")
        tab.focusEditor()
    }
    function findNext() {
        var tab = activeTab
        if (!tab || findField.text.length === 0) return
        var at = tab.text.indexOf(findField.text, Math.max(tab.cursorPosition, findStart))
        if (at < 0) at = tab.text.indexOf(findField.text, 0)
        if (at >= 0) { tab.select(at, at + findField.text.length); findStart = at + findField.text.length; tab.status = "Match found" }
        else tab.status = "No match"
    }
    function replaceOne() {
        if (!activeTab) return
        if (activeTab.selectedText === findField.text) { activeTab.insert(activeTab.selectionStart, replaceField.text); findStart = activeTab.cursorPosition }
        findNext()
    }
    function replaceAll() {
        if (!activeTab || findField.text.length === 0) return
        var count = activeTab.text.split(findField.text).length - 1
        activeTab.replaceText(activeTab.text.split(findField.text).join(replaceField.text))
        activeTab.status = count + " replacement" + (count === 1 ? "" : "s")
    }

    Component.onCompleted: {
        try { recentFiles = JSON.parse(state.recentFilesJson) } catch (e) { recentFiles = [] }
        addTab("")
    }
    onWidthChanged: if (width >= minimumWidth) state.windowWidth = width
    onHeightChanged: if (height >= minimumHeight) state.windowHeight = height
    onClosing: function(close) { if (!allowClose && tabs.some(function(tab) { return tab.dirty })) { close.accepted = false; requestCloseAll() } }

    FileDialog {
        id: openDialog
        title: "Open a note"
        nameFilters: ["Notes (*.md *.txt)", "All files (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: app.openPath(app.pathFromUrl(selectedFile))
    }
    FileDialog {
        id: saveDialog
        title: "Save note as"
        nameFilters: ["Markdown (*.md)", "Text (*.txt)"]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "md"
        onAccepted: { if (app.saveTarget) app.saveTarget.saveFileAs(app.pathFromUrl(selectedFile)); app.saveTarget = null }
        onRejected: { app.saveTarget = null; if (app.pendingAction !== "") { app.pendingAction = ""; app.pendingTab = null; app.closingAll = false } }
    }
    Dialog {
        id: unsavedDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: 370
        title: "Save changes?"
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        contentItem: Item {
            implicitWidth: 340
            implicitHeight: 64
            Label {
                anchors.fill: parent
                text: "Save changes to “" + (app.pendingTab ? app.pendingTab.basename() : "Untitled") + "”?"
                color: Theme.text
                padding: 14
                wrapMode: Text.WordWrap
            }
        }
        onAccepted: app.save(app.pendingTab)
        onDiscarded: {
            var action = app.pendingAction
            var tab = app.pendingTab
            app.pendingAction = ""
            app.pendingTab = null
            if (tab) app.removeTab(tab)
            if (action === "closeAll") app.requestCloseAll()
        }
        onRejected: { app.pendingAction = ""; app.pendingTab = null; app.closingAll = false }
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: app.addTab("") }
    Shortcut { sequence: "Ctrl+T"; onActivated: app.addTab("") }
    Shortcut { sequence: "Ctrl+W"; onActivated: app.closeTab(app.activeTab) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: { var i = app.tabs.indexOf(app.activeTab); app.switchTab(app.tabs[(i + 1) % app.tabs.length]) } }
    Shortcut { sequence: "Ctrl+O"; onActivated: openDialog.open() }
    Shortcut { sequence: "Ctrl+S"; onActivated: app.save(app.activeTab) }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: app.saveAs(app.activeTab) }
    Shortcut { sequence: "Ctrl+F"; onActivated: { findBar.visible = true; findField.forceActiveFocus(); findField.selectAll() } }
    Shortcut { sequence: "Ctrl+H"; onActivated: { findBar.visible = true; replaceField.visible = true; findField.forceActiveFocus() } }
    Shortcut { sequence: "Escape"; onActivated: { if (findBar.visible) { findBar.visible = false; app.activeTab.focusEditor() } } }
    Shortcut { sequence: "Ctrl+B"; onActivated: app.insertPair("**", "**") }
    Shortcut { sequence: "Ctrl+I"; onActivated: app.insertPair("*", "*") }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 38; color: Theme.surface
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 7
                spacing: 4
                Label { text: "N"; color: Theme.accent; font.family: Theme.fontFamily; font.bold: true; font.pixelSize: 16; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter }
                Flickable {
                    id: tabStrip
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: tabRow.implicitWidth
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: tabRow
                        height: parent.height
                        spacing: 2
                        Repeater {
                            model: app.tabs
                            delegate: Rectangle {
                                id: tabChip
                                required property var modelData
                                width: 150
                                height: 32
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 5
                                color: modelData === app.activeTab ? Theme.raised : "transparent"
                                border.width: modelData === app.activeTab ? 1 : 0
                                border.color: Theme.border
                                MouseArea { anchors.fill: parent; onClicked: app.switchTab(tabChip.modelData) }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 4
                                    spacing: 4
                                    Label { text: tabChip.modelData.dirty ? "●" : ""; color: Theme.accent; font.pixelSize: 10; visible: text !== "" }
                                    Label { text: tabChip.modelData.basename(); color: tabChip.modelData === app.activeTab ? Theme.text : Theme.muted; elide: Text.ElideRight; font.pixelSize: 12; Layout.fillWidth: true }
                                    ToolButton {
                                        id: closeTabButton
                                        text: "×"
                                        font.pixelSize: 15
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        padding: 0
                                        onClicked: app.closeTab(tabChip.modelData)
                                        background: Rectangle { radius: 4; color: closeTabButton.hovered ? Theme.border : "transparent" }
                                    }
                                }
                            }
                        }
                    }
                }
                ToolButton {
                    id: newTabButton
                    text: "+"
                    font.pixelSize: 19
                    implicitWidth: 30
                    implicitHeight: 30
                    padding: 0
                    onClicked: app.addTab("")
                    ToolTip.visible: hovered
                    ToolTip.text: "New tab (Ctrl+T)"
                    background: Rectangle { radius: 5; color: newTabButton.hovered ? Theme.raised : "transparent" }
                }
                ToolButton {
                    id: menuButton
                    text: "☰"
                    font.pixelSize: 17
                    implicitWidth: 32
                    implicitHeight: 30
                    padding: 0
                    onClicked: appMenu.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "Menu"
                    background: Rectangle { radius: 5; color: menuButton.hovered ? Theme.raised : "transparent" }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            Popup {
                id: appMenu
                parent: Overlay.overlay
                x: app.width - width - 8
                y: 41
                width: 264
                height: Math.min(app.height - 58, menuContent.implicitHeight + topPadding + bottomPadding)
                padding: 6
                clip: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle { color: Theme.surface; border.color: Theme.border; border.width: 1; radius: 8 }
                contentItem: Flickable {
                    id: menuFlickable
                    contentWidth: width
                    contentHeight: menuContent.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: menuContent.implicitHeight > appMenu.height - 12 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                    ColumnLayout {
                        id: menuContent
                        width: menuFlickable.width
                        spacing: 1
                        Label { text: "FILES"; color: Theme.accent; font.pixelSize: 10; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 4; Layout.bottomMargin: 3 }
                        ThemedMenuButton { text: "New tab"; shortcutText: "Ctrl+T"; onClicked: { app.addTab(""); appMenu.close() } }
                        ThemedMenuButton { text: "Open…"; shortcutText: "Ctrl+O"; onClicked: { openDialog.open(); appMenu.close() } }
                        ThemedMenuButton { text: "Save"; shortcutText: "Ctrl+S"; enabled: app.activeTab && app.activeTab.dirty; onClicked: { app.save(app.activeTab); appMenu.close() } }
                        ThemedMenuButton { text: "Save as…"; shortcutText: "Ctrl+Shift+S"; onClicked: { app.saveAs(app.activeTab); appMenu.close() } }
                        ThemedMenuButton { text: "Close tab"; shortcutText: "Ctrl+W"; onClicked: { app.closeTab(app.activeTab); appMenu.close() } }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 5; Layout.bottomMargin: 5; color: Theme.border }
                        Label { text: "EDIT"; color: Theme.accent; font.pixelSize: 10; font.bold: true; Layout.leftMargin: 10; Layout.bottomMargin: 3 }
                        ThemedMenuButton { text: "Undo"; shortcutText: "Ctrl+Z"; enabled: app.activeTab && app.activeTab.canUndo; onClicked: { app.activeTab.undo(); appMenu.close() } }
                        ThemedMenuButton { text: "Redo"; shortcutText: "Ctrl+Shift+Z"; enabled: app.activeTab && app.activeTab.canRedo; onClicked: { app.activeTab.redo(); appMenu.close() } }
                        ThemedMenuButton { text: "Find"; shortcutText: "Ctrl+F"; onClicked: { findBar.visible = true; findField.forceActiveFocus(); findField.selectAll(); appMenu.close() } }
                        ThemedMenuButton { text: "Find and replace"; shortcutText: "Ctrl+H"; onClicked: { findBar.visible = true; replaceField.visible = true; findField.forceActiveFocus(); appMenu.close() } }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 5; Layout.bottomMargin: 5; color: Theme.border }
                        Label { text: "MARKDOWN"; color: Theme.accent; font.pixelSize: 10; font.bold: true; Layout.leftMargin: 10; Layout.bottomMargin: 3 }
                        ThemedMenuButton { text: "Bold"; shortcutText: "Ctrl+B"; onClicked: { app.insertPair("**", "**"); appMenu.close() } }
                        ThemedMenuButton { text: "Italic"; shortcutText: "Ctrl+I"; onClicked: { app.insertPair("*", "*"); appMenu.close() } }
                        ThemedMenuButton { text: "Heading 1"; onClicked: { app.heading(1); appMenu.close() } }
                        ThemedMenuButton { text: "Heading 2"; onClicked: { app.heading(2); appMenu.close() } }
                        ThemedMenuButton { text: "Bullet list"; onClicked: { app.prefixLines("- ", false); appMenu.close() } }
                        ThemedMenuButton { text: "Numbered list"; onClicked: { app.prefixLines("", true); appMenu.close() } }
                        ThemedMenuButton { text: "Inline code"; onClicked: { app.insertPair("`", "`"); appMenu.close() } }
                        ThemedMenuButton { text: "Link"; onClicked: { app.insertPair("[", "](https://)"); appMenu.close() } }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 5; Layout.bottomMargin: 5; color: Theme.border }
                        Label { text: "VIEW"; color: Theme.accent; font.pixelSize: 10; font.bold: true; Layout.leftMargin: 10; Layout.bottomMargin: 3 }
                        ThemedMenuButton { text: app.wrapEnabled ? "✓  Word wrap" : "Word wrap"; onClicked: { app.wrapEnabled = !app.wrapEnabled; state.wrapEnabled = app.wrapEnabled } }
                        Label { text: "RECENT FILES"; color: Theme.accent; visible: app.recentFiles.length > 0; font.pixelSize: 10; font.bold: true; Layout.leftMargin: 10; Layout.topMargin: 9; Layout.bottomMargin: 3 }
                        Repeater {
                            model: app.recentFiles
                            delegate: ThemedMenuButton {
                                required property string modelData
                                text: app.basename(modelData)
                                onClicked: { app.openPath(modelData); appMenu.close() }
                            }
                        }
                        ThemedMenuButton { text: "Clear recent files"; visible: app.recentFiles.length > 0; onClicked: { app.recentFiles = []; state.recentFilesJson = "[]"; appMenu.close() } }
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
                ToolButton { text: "×"; onClicked: { findBar.visible = false; if (app.activeTab) app.activeTab.focusEditor() } }
            }
        }
        Rectangle {
            id: documentHost
            Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.bg
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 25; color: Theme.surface
            RowLayout { anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11
                Label { text: app.activeTab ? (app.activeTab.path || "Unsaved note") : ""; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.fillWidth: true }
                Label { text: app.activeTab ? (app.activeTab.dirty ? "Modified" : app.activeTab.status) : ""; color: app.activeTab && app.activeTab.dirty ? Theme.accent : Theme.muted; font.pixelSize: 11 }
                Label { text: app.activeTab ? app.activeTab.lineColumn() : ""; color: Theme.muted; font.pixelSize: 11; Layout.leftMargin: 10 }
                Label { text: app.activeTab ? app.activeTab.text.length + " chars" : ""; color: Theme.muted; font.pixelSize: 11; Layout.leftMargin: 9 }
            }
        }
    }
}
