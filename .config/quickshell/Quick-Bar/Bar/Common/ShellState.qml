pragma Singleton
import QtQuick

// État global du shell.
// WiFi / Bluetooth / DND / Hotspot / Focus / ScreenRecord — écrits par QuickSettings.

QtObject {
    id: root

    property int topBarLWidth: 0
    property int topBarCWidth: 0
    property int topBarRWidth: 0

    property bool focusMode:    false
    property bool dnd:          false
    property bool screenRecord: false
    property bool hotspot:      false
    property bool airplane:     false

    // WiFi — false quand la radio est coupée OU que le hotspot occupe l'interface
    property bool wifiOn: false

    // VPN
    property bool   vpnActive:     false
    property bool   vpnConnecting: false
    property string vpnName:       ""

    // Bluetooth
    property bool btPowered:   false
    property bool btConnected: false

    // Fournisseur de config (conservé pour compat ; non utilisé dans Quick-Bar)
    property string configProvider: "lua"
}
