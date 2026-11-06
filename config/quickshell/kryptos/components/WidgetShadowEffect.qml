import QtQuick

// KryptOS: QtQuick.Effects (RectangularShadow / MultiEffect) is not available
// in the live image's Qt build, so this is a no-op placeholder that keeps the
// caller contract (cornerRadius) intact. Layer surfaces get their shadow from
// the Hyprland compositor; Panel.qml keeps the same child as before.
Item {
    id: root

    // Caller supplies the panel corner radius (uniform; frame-join panels
    // disable this effect entirely while emerging).
    required property real cornerRadius
}
