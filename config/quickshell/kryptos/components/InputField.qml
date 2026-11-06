import QtQuick
import ".."

// Plain-TextInput stand-in for QtQuick.Controls.TextField: this image is built
// without qtquickcontrols2, so the shell keeps its own minimal field.
Item {
    id: field

    implicitHeight: 32
    property real radius: 8
    property Item background: Rectangle {
        color: ThemeManager.cardColor
        radius: field.radius
    }

    property alias text: input.text
    property alias font: input.font
    property alias color: input.color
    property alias readOnly: input.readOnly
    property alias echoMode: input.echoMode
    property alias validator: input.validator
    property alias inputMethodHints: input.inputMethodHints
    property alias selectionColor: input.selectionColor
    property alias selectedTextColor: input.selectedTextColor
    property alias horizontalAlignment: input.horizontalAlignment
    property alias verticalAlignment: input.verticalAlignment
    property alias selectByMouse: input.selectByMouse
    property alias cursorPosition: input.cursorPosition
    property alias placeholderText: placeholder.text
    property color placeholderTextColor: ThemeManager.placeholderColor

    // Item.activeFocus is FINAL, so callers use this instead of
    // field.forceActiveFocus() to put the caret in the inner TextInput.
    function focusInput() {
        input.forceActiveFocus()
    }

    signal accepted()
    signal editingFinished()

    onBackgroundChanged: if (background) attachBackground()
    Component.onCompleted: attachBackground()

    function attachBackground() {
        if (!background)
            return
        background.parent = field
        background.anchors.fill = field
        background.z = -1
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        onAccepted: field.accepted()
        onEditingFinished: field.editingFinished()
    }

    Text {
        id: placeholder
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        color: field.placeholderTextColor
        font: field.font
        elide: Text.ElideRight
        visible: input.text.length === 0 && !input.activeFocus
    }
}
