pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PopoutComponent {
    id: root

    required property var portWatch

    headerText: "Port Watch"
    detailsText: portWatch.summaryText
    showCloseButton: true

    property bool listeningExpanded: true
    property bool appsExpanded: false
    property bool systemExpanded: false

    function syncOpenState() {
        if (!root.portWatch)
            return

        const visibleNow = root.parentPopout?.shouldBeVisible ?? false
        root.portWatch.panelOpen = visibleNow

        if (visibleNow)
            root.portWatch.refresh()
    }

    onParentPopoutChanged: syncOpenState()

    Connections {
        target: root.parentPopout

        function onShouldBeVisibleChanged() {
            root.syncOpenState()
        }
    }

    Component.onDestruction: {
        if (root.portWatch)
            root.portWatch.panelOpen = false
    }

    component SectionHeader: Rectangle {
        id: section

        required property string label
        required property int count
        required property bool expanded

        signal toggled()

        width: parent ? parent.width : 0
        height: 36
        radius: Theme.cornerRadiusSmall
        color: sectionMouse.containsMouse
            ? Theme.withAlpha(Theme.surfaceText, 0.07)
            : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            spacing: Theme.spacingS

            DankIcon {
                name: section.expanded ? "expand_more" : "chevron_right"
                size: Theme.iconSizeSmall
                color: Theme.surfaceVariantText
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: section.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: "(" + section.count + ")"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: sectionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: section.toggled()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    component PortCard: Rectangle {
        id: card

        required property var modelData

        readonly property string rowKey:
            modelData.proto + ":" + modelData.port + ":" + modelData.pid
        readonly property bool armed:
            root.portWatch.armedKey === rowKey
        readonly property bool busy:
            root.portWatch.busyKey === rowKey
        readonly property bool errored:
            root.portWatch.errorKey === rowKey

        width: parent ? parent.width : 0
        height: modelData.detail !== "" ? 78 : 64
        radius: Theme.cornerRadius
        clip: true
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: card.errored
            ? Theme.error
            : Theme.withAlpha(Theme.surfaceText, 0.08)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingS

            Rectangle {
                Layout.preferredWidth: 36
                Layout.minimumWidth: 36
                Layout.maximumWidth: 36
                Layout.preferredHeight: 36
                Layout.minimumHeight: 36
                Layout.maximumHeight: 36
                radius: Theme.cornerRadiusSmall
                color: card.errored
                    ? Theme.withAlpha(Theme.error, 0.14)
                    : Theme.withAlpha(Theme.primary, 0.10)
                Layout.alignment: Qt.AlignVCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: card.modelData.proto === "tcp" ? "lan" : "swap_vert"
                    size: Theme.iconSizeSmall
                    color: card.errored ? Theme.error : Theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: ":" + card.modelData.port + "  ·  " + card.modelData.proto.toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.errored
                        ? root.portWatch.errorText
                        : card.modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: card.errored ? Theme.error : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: card.modelData.detail !== ""
                    text: card.modelData.detail
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.78)
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                id: killButton

                // Keep this width fixed. Changing width when arming inside a
                // Flickable can move the click target between Kill/Confirm.
                readonly property real buttonWidth: 98

                Layout.preferredWidth: buttonWidth
                Layout.minimumWidth: buttonWidth
                Layout.maximumWidth: buttonWidth
                Layout.preferredHeight: 36
                Layout.minimumHeight: 36
                Layout.maximumHeight: 36
                Layout.alignment: Qt.AlignVCenter

                radius: Theme.cornerRadiusSmall
                color: card.armed
                    ? Theme.withAlpha(Theme.error, killMouse.containsMouse ? 0.22 : 0.14)
                    : Theme.withAlpha(Theme.surfaceText, killMouse.containsMouse ? 0.11 : 0.055)
                border.width: 1
                border.color: card.armed
                    ? Theme.withAlpha(Theme.error, 0.62)
                    : Theme.withAlpha(Theme.surfaceText, killMouse.containsMouse ? 0.20 : 0.11)
                opacity: card.busy ? 0.55 : 1.0

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    DankIcon {
                        name: card.busy ? "progress_activity" : "stop_circle"
                        size: Theme.iconSizeSmall
                        color: card.armed ? Theme.error : Theme.surfaceText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: card.busy ? "…" : (card.armed ? "Confirm" : "Kill")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: card.armed ? Theme.error : Theme.surfaceText
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    id: killMouse
                    anchors.fill: parent
                    enabled: !card.busy
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.portWatch.requestKill(card.modelData)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }

            }
        }
    }

    Column {
        id: content

        width: parent.width
        spacing: Theme.spacingS
        bottomPadding: Theme.spacingS

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                text: root.portWatch.errorText !== ""
                    ? root.portWatch.errorText
                    : "Listening sockets on this machine"
                font.family: Theme.fontFamily
                color: root.portWatch.errorText !== ""
                    ? Theme.error
                    : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.minimumWidth: 34
                Layout.maximumWidth: 34
                Layout.preferredHeight: 34
                Layout.minimumHeight: 34
                Layout.maximumHeight: 34
                radius: Theme.cornerRadiusSmall
                color: refreshMouse.containsMouse
                    ? Theme.withAlpha(Theme.surfaceText, 0.10)
                    : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: Theme.iconSizeSmall
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.portWatch.refresh()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }
        }

        Flickable {
            id: portsFlick

            width: parent.width
            height: Math.min(listColumn.implicitHeight, 470)
            contentWidth: width
            contentHeight: listColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            Column {
                id: listColumn

                width: portsFlick.width
                spacing: Theme.spacingS

                SectionHeader {
                    label: "LISTENING"
                    count: root.portWatch.ownPorts.length
                    expanded: root.listeningExpanded
                    onToggled: root.listeningExpanded = !root.listeningExpanded
                }

                Repeater {
                    model: root.listeningExpanded ? root.portWatch.ownPorts : []

                    delegate: PortCard {
                        width: listColumn.width
                    }
                }

                StyledText {
                    visible: root.portWatch.totalPorts === 0
                    width: parent.width
                    text: "No listening ports detected"
                    font.family: Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    topPadding: Theme.spacingM
                    bottomPadding: Theme.spacingM
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.surfaceText, 0.08)
                }

                SectionHeader {
                    label: "APPS"
                    count: root.portWatch.appPorts.length
                    expanded: root.appsExpanded
                    onToggled: root.appsExpanded = !root.appsExpanded
                }

                Repeater {
                    model: root.appsExpanded ? root.portWatch.appPorts : []

                    delegate: PortCard {
                        width: listColumn.width
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.surfaceText, 0.08)
                }

                SectionHeader {
                    label: "SYSTEM"
                    count: root.portWatch.systemPorts.length
                    expanded: root.systemExpanded
                    onToggled: root.systemExpanded = !root.systemExpanded
                }

                Repeater {
                    model: root.systemExpanded ? root.portWatch.systemPorts : []

                    delegate: PortCard {
                        width: listColumn.width
                    }
                }
            }
        }
    }
}
