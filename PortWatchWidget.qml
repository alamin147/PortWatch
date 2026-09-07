import QtQuick

import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property PortWatchModel portWatch: PortWatchModel {}

    popoutWidth: 430
    popoutHeight: 0

    horizontalBarPill: Component {
        PortWatchHorizontalPill {
            portWatch: root.portWatch
            iconSize: root.iconSize
        }
    }

    verticalBarPill: Component {
        PortWatchVerticalPill {
            portWatch: root.portWatch
            iconSize: root.iconSize
        }
    }

    popoutContent: Component {
        PortWatchPopout {
            portWatch: root.portWatch
        }
    }

    // Match the Omarchy plugin behavior: right-click the bar icon to refresh.
    pillRightClickAction: () => root.portWatch.refresh()
}
