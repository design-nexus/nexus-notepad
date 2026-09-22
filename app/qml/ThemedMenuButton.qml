import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Button {
    id: control
    Layout.fillWidth: true
    implicitHeight: 30
    property string shortcutText: ""

    contentItem: RowLayout {
        spacing: 6
        Label {
            text: control.text
            color: control.enabled ? Theme.text : Theme.muted
            font: control.font
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Label {
            text: control.shortcutText
            color: Theme.muted
            font.pixelSize: 11
            visible: text !== ""
        }
    }
    leftPadding: 10
    rightPadding: 10
    background: Rectangle {
        radius: 4
        color: control.down || control.hovered ? Theme.raised : Theme.surface
        border.width: control.hovered ? 1 : 0
        border.color: Theme.border
    }
}
