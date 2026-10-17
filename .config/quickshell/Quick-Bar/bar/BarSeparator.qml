import QtQuick
import qs.core
import qs.core.functions

Rectangle {
    implicitWidth:  Appearance.bar.vertical ? 16 : 1
    implicitHeight: Appearance.bar.vertical ? 1 : 16
    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.28)
}
