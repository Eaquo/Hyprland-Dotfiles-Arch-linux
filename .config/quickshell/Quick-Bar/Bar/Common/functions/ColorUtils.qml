pragma Singleton
import Quickshell

Singleton {
    id: root

    function mix(color1, color2, percentage) {
        var p = (percentage === undefined) ? 0.5 : percentage
        var c1 = Qt.color(color1), c2 = Qt.color(color2)

        return Qt.rgba(
            (1 - p) * c1.r + p * c2.r,
            (1 - p) * c1.g + p * c2.g,
            (1 - p) * c1.b + p * c2.b,
            (1 - p) * c1.a + p * c2.a
        )
    }

    function transparentize(color, percentage) {
        var p = (percentage === undefined) ? 1 : percentage
        var c = Qt.color(color)
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - p))
    }

    function applyAlpha(color, alpha) {
        if (!color || color === "") color = "#000000"
        var c = Qt.color(color)
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, alpha)))
    }

    function withLightness(color, lightness) {
        var c = Qt.color(color)
        return Qt.hsla(c.hslHue, c.hslSaturation, lightness, c.a)
    }
}
