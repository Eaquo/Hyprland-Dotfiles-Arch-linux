pragma Singleton
import QtQuick

// ClockState — état des modules horloge (timer / chrono / alarmes).
// Écrit par ClockCard, lu par le dashboard.

QtObject {
    // Timer
    property bool   timerRunning: false
    property bool   timerStarted: false
    property int    timerLeft:    0
    property int    timerTotal:   0
    property string timerDisplay: "00:00"

    // Chronomètre
    property bool   swRunning: false
    property bool   swStarted: false
    property string swDisplay: "00:00"

    signal requestStopwatchReset()
    signal requestTimerReset()

    // Alarmes — liste de { id, hour, minute, label, enabled }
    property var alarms: []

    // Prochaine alarme active : { hour, minute, label, minsUntil } ou null
    property var nextAlarm: null

    readonly property bool hasActiveEvent:
        timerRunning || swRunning || nextAlarm !== null
}
