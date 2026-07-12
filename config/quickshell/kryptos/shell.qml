pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool launcherOpen: false
    readonly property color background: "#160f28"
    readonly property color surface: "#21163b"
    readonly property color surfaceRaised: "#302052"
    readonly property color accent: "#7c3aed"
    readonly property color secondary: "#2dd4bf"
    readonly property color foreground: "#eeeaf6"
    readonly property color muted: "#aaa2ba"

    readonly property var filteredApps: {
        const query = commandInput.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values;
        if (!query)
            return apps.slice(0, 8);
        return apps.filter(entry => {
            const name = (entry.name || "").toLowerCase();
            const generic = (entry.genericName || "").toLowerCase();
            const id = (entry.id || "").toLowerCase();
            return name.includes(query) || generic.includes(query) || id.includes(query);
        }).slice(0, 8);
    }

    function closeLauncher() {
        launcherOpen = false;
        commandInput.text = "";
    }

    function launchSelection() {
        const index = appList.currentIndex;
        if (index >= 0 && index < filteredApps.length) {
            filteredApps[index].execute();
            closeLauncher();
            return;
        }

        const command = commandInput.text.trim();
        if (command.length > 0)
            Quickshell.execDetached(["/bin/sh", "-lc", command]);
        closeLauncher();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.launcherOpen = !root.launcherOpen;
        }

        function open() {
            root.launcherOpen = true;
        }

        function close() {
            root.closeLauncher();
        }
    }

    PanelWindow {
        id: bar
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 42
        exclusiveZone: 42
        color: root.background

        Rectangle {
            anchors.fill: parent
            color: root.background
            border.color: root.surfaceRaised
            border.width: 1

            Row {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                height: 30
                spacing: 8

                Rectangle {
                    width: 92
                    height: 30
                    radius: 6
                    color: launcherMouse.containsMouse ? root.accent : root.surfaceRaised

                    Text {
                        anchors.centerIn: parent
                        text: "KRYPTOS"
                        color: root.foreground
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launcherOpen = !root.launcherOpen
                    }
                }

                Repeater {
                    model: 5

                    Rectangle {
                        id: workspaceButton
                        required property int index
                        readonly property int workspace: index + 1
                        width: 30
                        height: 30
                        radius: 6
                        color: Hyprland.focusedWorkspace
                            && Hyprland.focusedWorkspace.id === workspace
                            ? root.accent : workspaceMouse.containsMouse
                            ? root.surfaceRaised : root.surface

                        Text {
                            anchors.centerIn: parent
                            text: workspaceButton.workspace
                            color: root.foreground
                            font.bold: Hyprland.focusedWorkspace
                                && Hyprland.focusedWorkspace.id === workspaceButton.workspace
                        }

                        MouseArea {
                            id: workspaceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "hyprctl", "dispatch", "workspace",
                                String(workspaceButton.workspace)
                            ])
                        }
                    }
                }
            }

            Row {
                anchors {
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                spacing: 14

                Text {
                    text: "DEV"
                    color: root.secondary
                    font.bold: true
                    font.pixelSize: 11
                }

                Text {
                    text: Qt.locale().toString(clock.date, "ddd MMM d  HH:mm")
                    color: root.foreground
                    font.pixelSize: 12
                }
            }
        }
    }

    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        anchors {
            top: true
            left: true
            right: true
        }
        margins.top: 56
        implicitHeight: 410
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => commandInput.forceActiveFocus());
        }

        Rectangle {
            width: Math.min(620, parent.width - 32)
            height: 390
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.surface
            radius: 8
            border.color: root.accent
            border.width: 1

            TextInput {
                id: commandInput
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                height: 46
                leftPadding: 14
                rightPadding: 14
                verticalAlignment: TextInput.AlignVCenter
                color: root.foreground
                selectionColor: root.accent
                selectedTextColor: root.foreground
                font.pixelSize: 16
                clip: true

                Rectangle {
                    anchors.fill: parent
                    z: -1
                    radius: 6
                    color: root.background
                    border.color: commandInput.activeFocus ? root.secondary : root.surfaceRaised
                    border.width: 1
                }

                Text {
                    visible: commandInput.text.length === 0
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Search applications or run command"
                    color: root.muted
                    font.pixelSize: 15
                }

                onTextChanged: appList.currentIndex = filteredApps.length > 0 ? 0 : -1
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        appList.currentIndex = Math.min(appList.count - 1, appList.currentIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        appList.currentIndex = Math.max(0, appList.currentIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.closeLauncher();
                        event.accepted = true;
                    }
                }
            }

            ListView {
                id: appList
                anchors {
                    top: commandInput.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 16
                }
                spacing: 6
                clip: true
                model: root.filteredApps
                currentIndex: count > 0 ? 0 : -1

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 38
                    radius: 6
                    color: ListView.isCurrentItem || appMouse.containsMouse
                        ? root.surfaceRaised : "transparent"

                    Rectangle {
                        width: 4
                        height: 20
                        radius: 2
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        color: appRow.ListView.isCurrentItem ? root.secondary : "transparent"
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 24
                            right: parent.right
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        text: appRow.modelData.name
                        color: root.foreground
                        elide: Text.ElideRight
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appList.currentIndex = appRow.index;
                            root.launchSelection();
                        }
                    }
                }
            }
        }
    }
}
