import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// AnimPage — Réglages › Apparence › Animations : vitesse globale ([theme] anim_speed).
// Toutes les durées de Quick-Bar passent par Appearance.dur(ms) (sauf les boucles continues).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Animations"; sub: "[theme] anim_speed dans config.toml" }

    SetCard {
        title: "Vitesse"
        SetRow {
            title: "Vitesse des animations"
            desc: "ouverture des panneaux, onglets, survols, carrousels… « Aucune » rend tout instantané."
            SetSeg {
                options: [[1, "Normale"], [0.6, "Rapide"], [0.35, "Très rapide"], [0, "Aucune"]]
                current: Appearance.animSpeed
                onPicked: (v) => { Config.set("theme.anim_speed", v === 1 ? null : v); demo.play() }
            }
        }

        // Démo : la même ouverture que les panneaux (ligne → pilule → déroulé), à la vitesse choisie
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 190
            radius: 12
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
            clip: true

            Item {
                id: demo
                anchors.fill: parent
                property real w: 300
                property real h: 130
                property real r: 14
                property real c: 1
                function play() { anim.restart() }
                SequentialAnimation {
                    id: anim
                    ScriptAction { script: { demo.w = 2; demo.h = 2; demo.r = 1; demo.c = 0 } }
                    NumberAnimation { target: demo; property: "w"; to: 240; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                    ParallelAnimation {
                        NumberAnimation { target: demo; property: "h"; to: 30; duration: Appearance.dur(300); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                        NumberAnimation { target: demo; property: "r"; to: 15; duration: Appearance.dur(300) }
                        NumberAnimation { target: demo; property: "w"; to: 300; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: demo; property: "h"; to: 130; duration: Appearance.dur(460); easing.type: Easing.OutCubic }
                        NumberAnimation { target: demo; property: "r"; to: 14; duration: Appearance.dur(460) }
                        SequentialAnimation {
                            PauseAnimation { duration: Appearance.dur(220) }
                            NumberAnimation { target: demo; property: "c"; to: 1; duration: Appearance.dur(300) }
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: demo.w; height: demo.h; radius: Math.min(demo.r, height / 2)
                    color: Appearance.colors.bg
                    border.width: 2; border.color: Appearance.colors.accent
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: demo.c
                        Rectangle { width: 200; height: 10; radius: 5; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.5) }
                        Rectangle { width: 140; height: 8; radius: 4; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25) }
                        Rectangle { width: 200; height: 26; radius: 8; color: Appearance.colors.accent }
                    }
                }
            }
            SetButton {
                anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
                label: "󰐊  Rejouer"; onTap: demo.play()
            }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Les boucles continues (spinners, contour en dégradé, visualiseur) gardent leur rythme : le contour se règle dans Thème."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
    }
}
