import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Button {
    id: control
    Layout.fillWidth: true
    implicitHeight: 34

    contentItem: Label {
        text: control.text
        color: control.enabled ? Theme.text : Theme.muted
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        leftPadding: 12
        rightPadding: 12
    }
    background: Rectangle {
        radius: 5
        color: control.down || control.hovered ? Theme.raised : Theme.surface
        border.width: control.hovered ? 1 : 0
        border.color: Theme.border
    }
}
