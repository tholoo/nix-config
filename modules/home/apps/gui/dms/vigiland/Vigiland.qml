import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool active: false
    property bool busy: false
    property string controlCommand: pluginData.controlCommand || ""

    pillClickAction: () => root.toggleVigiland()

    horizontalBarPill: Component {
        DankIcon {
            name: root.busy ? "hourglass_top" : "coffee"
            size: root.iconSize
            color: root.active ? Theme.primary : Theme.surfaceVariantText
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: root.busy ? "hourglass_top" : "coffee"
            size: root.iconSize
            color: root.active ? Theme.primary : Theme.surfaceVariantText
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.controlCommand !== ""
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: Qt.callLater(root.refreshStatus)
    onControlCommandChanged: refreshStatus()

    function refreshStatus() {
        if (!controlCommand || busy)
            return;

        Proc.runCommand("", [controlCommand, "status"], (output, exitCode) => {
            if (root.busy || exitCode !== 0)
                return;

            try {
                const status = JSON.parse(output.trim());
                root.active = status.alt === "active";
            } catch (error) {
                console.warn("Vigiland: invalid status response", error);
            }
        }, 0);
    }

    function toggleVigiland() {
        if (!controlCommand || busy)
            return;

        busy = true;
        Proc.runCommand("", [controlCommand, "toggle"], (_output, exitCode) => {
            root.busy = false;
            if (exitCode === 0) {
                root.refreshStatus();
            } else {
                ToastService.showError("Vigiland", "Could not toggle the idle inhibitor");
            }
        }, 0);
    }
}
