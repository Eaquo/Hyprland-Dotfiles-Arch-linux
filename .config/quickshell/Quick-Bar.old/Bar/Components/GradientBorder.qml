import QtQuick
import "../Common/"

// Contour arrondi tracé avec un dégradé 45° des couleurs wallust qui défile.
// Léger en mémoire (un Canvas), mais repeint à chaque avancée de phase tant
// qu'il est visible — la phase ne tourne que si `visible` est vrai.
Canvas {
    id: gb

    property real radius:      Appearance.bar.radius
    property int  borderWidth: 2
    property real phase:       0          // 0..1 → fait défiler les couleurs
    // Couleurs du défilement (objets color) — palette wallust par défaut.
    property var  colors:      Appearance.legiblePalette
    onColorsChanged:      requestPaint()

    onPhaseChanged:       requestPaint()
    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onRadiusChanged:      requestPaint()
    onBorderWidthChanged: requestPaint()

    // Avance la phase ~30 fps quand le contour est visible (cycle ~5,5 s)
    Timer {
        running:  gb.visible
        interval: 33; repeat: true
        onTriggered: gb.phase = (gb.phase + 0.006) % 1.0
    }

    // Couleur cyclique interpolée sur la palette wallust → string rgb()
    function _rainbowAt(t) {
        var c = gb.colors                        // défaut : couleurs vives & lisibles wallust
        var n = c.length
        if (n === 0) return "rgb(255,255,255)"
        var x = (((t % 1) + 1) % 1) * n
        var i = Math.floor(x) % n
        var j = (i + 1) % n
        var f = x - Math.floor(x)
        var a = c[i], b = c[j]
        var R = Math.round((a.r + (b.r - a.r) * f) * 255)
        var G = Math.round((a.g + (b.g - a.g) * f) * 255)
        var B = Math.round((a.b + (b.b - a.b) * f) * 255)
        return "rgb(" + R + "," + G + "," + B + ")"
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var w = width, h = height, bw = gb.borderWidth
        var inset = bw / 2
        var rr = Math.max(0, gb.radius - inset)
        var x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset

        ctx.beginPath()
        ctx.moveTo(x0 + rr, y0)
        ctx.lineTo(x1 - rr, y0)
        ctx.arcTo(x1, y0, x1, y0 + rr, rr)
        ctx.lineTo(x1, y1 - rr)
        ctx.arcTo(x1, y1, x1 - rr, y1, rr)
        ctx.lineTo(x0 + rr, y1)
        ctx.arcTo(x0, y1, x0, y1 - rr, rr)
        ctx.lineTo(x0, y0 + rr)
        ctx.arcTo(x0, y0, x0 + rr, y0, rr)
        ctx.closePath()

        var grad = ctx.createLinearGradient(0, 0, (w + h) / 2, (w + h) / 2)  // 45°
        var steps = 20
        for (var k = 0; k <= steps; k++) {
            var p = k / steps
            grad.addColorStop(p, gb._rainbowAt(p + gb.phase))
        }
        ctx.strokeStyle = grad
        ctx.lineWidth   = bw
        ctx.stroke()
    }
}
