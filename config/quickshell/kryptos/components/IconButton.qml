import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string glyph: ""
    property color glyphColor: ThemeManager.fgPrimary
    property int pixelSize: ThemeManager.fontSizeIcon
    property real hoverScale: ThemeManager.iconHoverScale
    property real pressScale: ThemeManager.iconPressScale
    // Nudges the glyph within its own fixed-size box without moving/resizing
    // the button itself. Useful when a container is already flush against a
    // screen edge and can't grow further in that direction.
    property real glyphOffsetY: 0
    property bool compact: false
    // Optional image mark. When set it replaces the Nerd Font glyph; ordinary
    // icon buttons leave it empty and keep using their glyph.
    property url imageSource: ""
    property real imageScale: 0.85
    signal clicked()

    width: compact ? pixelSize + 12 : 46
    height: 40
    radius: 10
    color: "transparent"

    scale: mouse.pressed ? root.pressScale : (mouse.containsMouse ? root.hoverScale : 1.0)
    Behavior on scale {
        SpringAnimation { spring: ThemeManager.bounceSpring; damping: ThemeManager.bounceDamping; mass: ThemeManager.bounceMass }
    }

    Image {
        id: glyphImage
        anchors.centerIn: parent
        width: Math.round(Math.min(root.width, root.height) * root.imageScale)
        height: width
        source: root.imageSource
        sourceSize.width: Math.max(1, Math.round(width))
        sourceSize.height: Math.max(1, Math.round(height))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: root.imageSource.toString().length > 0
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.glyphOffsetY
        text: root.glyph
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.pixelSize
        color: root.glyphColor
        visible: root.imageSource.toString().length === 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
