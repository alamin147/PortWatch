import QtQuick

import qs.Common
import qs.Widgets

Column {
    id: root

    required property var portWatch
    required property int iconSize

    spacing: 0

    DankIcon {
        name: "dns"
        size: root.iconSize
        color: root.portWatch.totalPorts > 0
            ? Theme.primary
            : Theme.surfaceVariantText
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
