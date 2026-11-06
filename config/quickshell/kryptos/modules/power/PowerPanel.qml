import QtQuick

// Quickshell was built without the UPower service module.
Item {
    id: root
    property bool isVisible: false
    signal requestClose()
    implicitWidth: 320
    implicitHeight: 420
}
