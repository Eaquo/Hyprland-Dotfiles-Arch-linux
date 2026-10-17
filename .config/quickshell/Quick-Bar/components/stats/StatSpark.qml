import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// StatSpark — élément des cartes de stats (barre et pages System).
Canvas {
    id: sp
    property var series: []          // [[tableau, couleur, max]]
    Layout.fillWidth: true
    implicitHeight: 64
    Connections { target: SysData; function onHistRevChanged() { if (sp.visible) sp.requestPaint() } }
    onPaint: {
        const g = getContext("2d"), W = width, H = height
        g.clearRect(0, 0, W, H)
        g.strokeStyle = ColorUtils.applyAlpha(Appearance.colors.fg, 0.07); g.lineWidth = 1
        for (let y = 16; y < H; y += 16) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke() }
        for (const [a, c, max] of series) {
            if (a.length < 2) continue
            const step = W / 59, off = 60 - a.length, m = Math.max(max, 1e-9)
            const yOf = v => H - 4 - Math.min(1, v / m) * (H - 10)
            g.beginPath()
            a.forEach((v, i) => i ? g.lineTo((i + off) * step, yOf(v)) : g.moveTo((i + off) * step, yOf(v)))
            g.strokeStyle = c; g.lineWidth = 2; g.stroke()
            g.lineTo(W, H); g.lineTo(off * step, H); g.closePath()
            const gr = g.createLinearGradient(0, 0, 0, H)
            gr.addColorStop(0, ColorUtils.applyAlpha(c, 0.35)); gr.addColorStop(1, ColorUtils.applyAlpha(c, 0))
            g.fillStyle = gr; g.fill()
            g.beginPath(); g.arc(W - 3, yOf(a[a.length - 1]), 3.5, 0, 7); g.fillStyle = c; g.fill()
        }
    }
}
