import QtQuick
import QtQuick.Controls
import "."

MenuItem {
    id: control
    implicitWidth: 260
    implicitHeight: 36

    contentItem: Label {
        text: control.text
        color: control.enabled ? Theme.text : Theme.muted
        font: control.font
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        leftPadding: 13
        rightPadding: 13
    }
    background: Rectangle {
        radius: 5
        color: control.highlighted ? Theme.raised : Theme.surface
        border.width: control.highlighted ? 1 : 0
        border.color: Theme.border
    }
}
