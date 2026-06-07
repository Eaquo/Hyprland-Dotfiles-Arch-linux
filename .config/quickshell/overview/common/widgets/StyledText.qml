import QtQuick
import ".."

Text {
    id: root
    property bool animateChange: false

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    font {
        hintingPreference: Font.PreferFullHinting
        family: Appearance?.font.family.main ?? "cascadia code"
        pixelSize: Appearance?.font.pixelSize.small ?? 15
    }
    color: Appearance?.m3colors.m3onBackground ?? "white"
}
