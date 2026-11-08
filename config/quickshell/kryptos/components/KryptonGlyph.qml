import QtQuick
import ".."

// Small, single-color version of Krypton's KCC shield-and-circuit K mark.
// Draw as paths so the launcher stays sharp without an image or custom font.
Canvas {
    id: root

    property color glyphColor: ThemeManager.fgPrimary
    antialiasing: true

    onGlyphColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        const side = Math.min(width, height)
        if (side <= 0)
            return

        ctx.save()
        ctx.translate((width - side) / 2, (height - side) / 2)
        ctx.scale(side / 32, side / 32)
        ctx.strokeStyle = root.glyphColor
        ctx.fillStyle = root.glyphColor
        ctx.lineWidth = 1.8
        ctx.lineJoin = "round"
        ctx.lineCap = "round"

        // Open shield: leave room for the K's diagonal arms on the right.
        ctx.beginPath()
        ctx.moveTo(13.5, 2.5)
        ctx.bezierCurveTo(10.1, 5, 6.1, 6.5, 2.5, 7.2)
        ctx.lineTo(2.5, 17.3)
        ctx.bezierCurveTo(2.5, 23, 6, 27.3, 13.5, 30)
        ctx.lineTo(20.2, 25.8)
        ctx.stroke()

        // Bold K silhouette, simplified to remain legible at bar-icon sizes.
        ctx.beginPath()
        ctx.moveTo(13, 3)
        ctx.lineTo(15.8, 4.5)
        ctx.lineTo(15.8, 14.7)
        ctx.lineTo(24.5, 5.5)
        ctx.lineTo(29.5, 5.5)
        ctx.lineTo(19.3, 16.4)
        ctx.lineTo(29.5, 28)
        ctx.lineTo(24.5, 28)
        ctx.lineTo(15.8, 18.3)
        ctx.lineTo(15.8, 26.5)
        ctx.lineTo(13, 28.3)
        ctx.closePath()
        ctx.fill()

        // Circuit traces and open terminals retain the source mark's motif.
        ctx.lineWidth = 1.4
        ctx.beginPath()
        ctx.moveTo(6.2, 10)
        ctx.lineTo(6.2, 13.1)
        ctx.moveTo(10, 9)
        ctx.lineTo(10, 16.1)
        ctx.moveTo(5.5, 20.5)
        ctx.lineTo(8.5, 20.5)
        ctx.lineTo(8.5, 22.6)
        ctx.stroke()
        for (const terminal of [[6.2, 14.4], [10, 17.4], [8.5, 23.9]]) {
            ctx.beginPath()
            ctx.arc(terminal[0], terminal[1], 1.3, 0, Math.PI * 2)
            ctx.stroke()
        }
        ctx.restore()
    }
}
