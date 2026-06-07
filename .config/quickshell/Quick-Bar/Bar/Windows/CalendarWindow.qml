pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Common/"
import "../Common/functions/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: calWin
            required property var modelData
            screen: modelData

            visible: Appearance.calendarVisible
            WlrLayershell.namespace: "quickshell:calendar"
            WlrLayershell.layer:     WlrLayer.Overlay
            exclusiveZone: -1
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"

            readonly property real cardY: Appearance.bar.topMargin + Appearance.bar.height - 1

            // ── State ─────────────────────────────────────────────────
            property int viewYear:  new Date().getFullYear()
            property int viewMonth: new Date().getMonth()
            readonly property int todayYear:  new Date().getFullYear()
            readonly property int todayMonth: new Date().getMonth()
            readonly property int todayDay:   new Date().getDate()
            property string currentTime: ""

            // Cellules plus petites → moins large
            readonly property int cellSize: 28
            readonly property int cellGap:  3
            readonly property int gridW:    7 * (cellSize + cellGap) - cellGap  // ~209px

            readonly property var monthNames: [
                "Janvier","Février","Mars","Avril","Mai","Juin",
                "Juillet","Août","Septembre","Octobre","Novembre","Décembre"
            ]
            readonly property var dayHeaders: ["L","M","M","J","V","S","D"]

            property var cells: {
                var start = (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
                var total = new Date(viewYear, viewMonth + 1, 0).getDate()
                var arr = []
                for (var i = 0; i < start; i++) arr.push(0)
                for (var d = 1; d <= total; d++) arr.push(d)
                while (arr.length % 7 !== 0) arr.push(0)
                return arr
            }

            function updateTime() {
                currentTime = Qt.formatTime(new Date(), "HH:mm")
            }

            Timer {
                interval: 1000; running: Appearance.calendarVisible
                repeat: true; triggeredOnStart: true
                onTriggered: calWin.updateTime()
            }

            Connections {
                target: Appearance
                function onCalendarVisibleChanged() {
                    if (Appearance.calendarVisible) {
                        calWin.viewYear  = new Date().getFullYear()
                        calWin.viewMonth = new Date().getMonth()
                        calWin.updateTime()
                    }
                }
            }

            Timer {
                id: closeTimer
                interval: 120; repeat: false
                onTriggered: Appearance.calendarVisible = false
            }

            MouseArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                y: Appearance.bar.topMargin + Appearance.bar.height
                hoverEnabled: false
                onClicked: Appearance.calendarVisible = false
            }

            // ── Card ──────────────────────────────────────────────────
            Rectangle {
                id: calCard

                x: Math.max(8, Math.min(Appearance.calPopupX - width / 2, calWin.width - width - 8))
                y: calWin.cardY + 6

                width:  calWin.gridW + 36
                height: calContent.implicitHeight + 24

                radius: Appearance.bar.radius

                color:        ColorUtils.applyAlpha(Appearance.colors.bg, Appearance.bar.bgAlpha)
                border.color: Appearance.colors.color15
                border.width: 1

                opacity: Appearance.calendarVisible ? 1.0 : 0.0
                scale:   Appearance.calendarVisible ? 1.0 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                HoverHandler {
                    onHoveredChanged: hovered ? closeTimer.stop() : closeTimer.restart()
                }

                ColumnLayout {
                    id: calContent
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 14; rightMargin: 14; topMargin: 14
                    }
                    spacing: 10

                    // ── Heure + date ──────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        // Heure à gauche
                        Column {
                            spacing: 2

                            Text {
                                text: calWin.currentTime
                                font.family:    Appearance.font.family
                                font.pixelSize: 26
                                font.weight:    Font.Light
                                color:          Appearance.colors.fg
                            }

                            Text {
                                text: {
                                    var d  = new Date()
                                    var fr = Qt.locale("fr_FR")
                                    return fr.standaloneDayName(d.getDay(), Locale.LongFormat) + " " +
                                           calWin.todayDay + " " +
                                           calWin.monthNames[calWin.todayMonth].toLowerCase()
                                }
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.small - 3
                                color:          ColorUtils.applyAlpha(Appearance.colors.fg, 0.45)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Nav mois à droite — compacte
                        Row {
                            spacing: 2

                            Rectangle {
                                width: 22; height: 22; radius: 6
                                color: prevMo.containsMouse
                                    ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    font.pixelSize: Appearance.font.body - 1
                                    color: Appearance.colors.fg
                                }
                                MouseArea {
                                    id: prevMo; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (calWin.viewMonth === 0) { calWin.viewMonth = 11; calWin.viewYear-- }
                                        else calWin.viewMonth--
                                    }
                                }
                            }

                            // Mois + année entre les flèches
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: calWin.monthNames[calWin.viewMonth].substring(0, 3).toUpperCase() +
                                      " " + calWin.viewYear
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.small - 2
                                font.weight:    Font.Medium
                                color:          Appearance.colors.fg
                                topPadding:     2
                            }

                            Rectangle {
                                width: 22; height: 22; radius: 6
                                color: nextMo.containsMouse
                                    ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    font.pixelSize: Appearance.font.body - 1
                                    color: Appearance.colors.fg
                                }
                                MouseArea {
                                    id: nextMo; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (calWin.viewMonth === 11) { calWin.viewMonth = 0; calWin.viewYear++ }
                                        else calWin.viewMonth++
                                    }
                                }
                            }
                        }
                    }

                    // Séparateur
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                    }

                    // ── En-têtes jours ────────────────────────────────
                    Row {
                        spacing: calWin.cellGap
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: calWin.dayHeaders
                            Text {
                                required property string modelData
                                required property int    index
                                width: calWin.cellSize
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font.pixelSize: Appearance.font.small - 3
                                font.family:    Appearance.font.family
                                font.weight:    Font.Medium
                                color: index >= 5
                                    ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.55)
                                    : ColorUtils.applyAlpha(Appearance.colors.fg, 0.35)
                            }
                        }
                    }

                    // ── Grille jours ──────────────────────────────────
                    Grid {
                        Layout.alignment: Qt.AlignHCenter
                        columns: 7
                        columnSpacing: calWin.cellGap
                        rowSpacing: 2

                        Repeater {
                            model: calWin.cells

                            Rectangle {
                                required property int modelData
                                required property int index
                                property bool isToday:   modelData === calWin.todayDay
                                    && calWin.viewMonth === calWin.todayMonth
                                    && calWin.viewYear  === calWin.todayYear
                                property bool isEmpty:   modelData === 0
                                property bool isWeekend: index % 7 >= 5

                                width: calWin.cellSize; height: calWin.cellSize
                                radius: 7

                                color: isToday
                                    ? Appearance.colors.color15
                                    : dayMa.containsMouse && !isEmpty
                                        ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                                        : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }

                                // Point "aujourd'hui" dans les autres mois
                                Rectangle {
                                    visible: !parent.isToday && !parent.isEmpty && parent.modelData === calWin.todayDay
                                        && (calWin.viewMonth !== calWin.todayMonth || calWin.viewYear !== calWin.todayYear)
                                    width: 4; height: 4; radius: 2
                                    anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
                                    color: Appearance.colors.accent
                                    opacity: 0.5
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text:  parent.isEmpty ? "" : parent.modelData.toString()
                                    font.pixelSize: Appearance.font.small - 2
                                    font.family:    Appearance.font.family
                                    font.weight:    parent.isToday ? Font.DemiBold : Font.Normal
                                    color: parent.isToday    ? Appearance.colors.color0
                                         : parent.isEmpty    ? "transparent"
                                         : parent.isWeekend  ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.75)
                                         : Appearance.colors.fg
                                }

                                MouseArea {
                                    id: dayMa
                                    anchors.fill: parent
                                    hoverEnabled: !parent.isEmpty
                                    cursorShape:  parent.isEmpty ? Qt.ArrowCursor : Qt.PointingHandCursor
                                }
                            }
                        }
                    }

                    // Semaine de l'année — info discrète en bas
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: {
                            var d = new Date(calWin.viewYear, calWin.viewMonth, calWin.todayDay)
                            var start = new Date(d.getFullYear(), 0, 1)
                            var week = Math.ceil(((d - start) / 86400000 + start.getDay() + 1) / 7)
                            return "S" + week
                        }
                        font.family:    Appearance.font.family
                        font.pixelSize: Appearance.font.small - 3
                        color:          ColorUtils.applyAlpha(Appearance.colors.fg, 0.25)
                        bottomPadding:  2
                    }
                }
            }
        }
    }
}
