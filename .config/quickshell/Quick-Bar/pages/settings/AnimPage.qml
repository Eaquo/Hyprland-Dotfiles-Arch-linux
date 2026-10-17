import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// AnimPage — Réglages › Apparence › Animations : vitesse globale ([theme] anim_speed).
// Toutes les durées de Quick-Bar passent par Appearance.dur(ms) (sauf les boucles continues).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Animations"; sub: "[theme] anim_speed · page_anim dans config.toml" }

    SetCard {
        title: "Ouverture des onglets (panneau tactile)"
        resetKeys: ["theme.page_anim"]
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Comment une page apparaît quand tu changes d'onglet. Avec « Goutte », les cartes de System et Apps s'ouvrent aussi une à une. Survole un style pour le voir."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4; columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: [["morph", "Goutte", "goutte → pilule → déroulé"], ["curtain", "Rideau", "se déroule de haut en bas"],
                        ["zoom", "Zoom", "grossit avec un rebond"], ["rise", "Montée", "arrive du bas"],
                        ["slide", "Glissement", "du côté de l'onglet"], ["fade", "Fondu", "apparaît en douceur"],
                        ["none", "Aucune", "instantané"]]
                delegate: StyleTile { required property var modelData; style: modelData[0]; name: modelData[1]; desc: modelData[2] }
            }
        }
    }

    SetCard {
        title: "Vitesse"
        resetKeys: ["theme.anim_speed"]
        SetRow {
            title: "Vitesse des animations"
            desc: "ouverture des panneaux, onglets, survols, carrousels… « Aucune » rend tout instantané."
            SetSeg {
                options: [[1, "Normale"], [0.6, "Rapide"], [0.35, "Très rapide"], [0, "Aucune"]]
                current: Appearance.animSpeed
                onPicked: (v) => { Config.set("theme.anim_speed", v === 1 ? null : v); demo.play() }
            }
        }

        // Démo : le style d'ouverture choisi (Ouverture des onglets), en grand, à la vitesse choisie
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 190
            radius: 12
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
            clip: true
            AnimStage { id: demo; anchors.centerIn: parent; width: 300; height: 150; style: Appearance.pageAnim }
            Text {
                anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                text: "Aperçu : " + (({ morph: "Goutte", curtain: "Rideau", zoom: "Zoom", rise: "Montée", slide: "Glissement", fade: "Fondu", none: "Aucune" })[Appearance.pageAnim] || Appearance.pageAnim)
                font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 4; color: Appearance.colors.dim
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

    // Une carte de style avec son aperçu animé (rejoué au survol et au clic)
    component StyleTile: Rectangle {
        id: st
        property string style: ""
        property string name: ""
        property string desc: ""
        readonly property bool on: Appearance.pageAnim === style
        Layout.fillWidth: true
        implicitHeight: 128; radius: 12
        color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.10) : (ma.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent")
        border.width: on ? 2 : 1
        border.color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)

        AnimStage {
            id: stage
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
            width: 120; height: 62
            style: st.style
        }
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: stage.bottom; topMargin: 10 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: st.name + (st.on ? "  ✓" : "")
                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; font.weight: Font.DemiBold
                   color: st.on ? Appearance.colors.accent : Appearance.colors.fg }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: st.desc
                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 5; color: Appearance.colors.dim }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) stage.play()
            onClicked: { Config.set("theme.page_anim", st.style === "morph" ? null : st.style); stage.play() }
        }
    }

    // Aperçu d'un style d'ouverture : une mini « page » (barres) jouée comme dans le panneau tactile.
    // Les dimensions suivent la taille de la scène (120 × 62 pour les cartes, plus grand pour la démo).
    component AnimStage: Item {
        id: stage
        property string style: "morph"
        function play() { seq.restart() }
        readonly property real k: height / 62
        clip: true
        property real w: width; property real h: height; property real y0: 0
        property real o: 1; property real sc: 1; property real dx: 0; property real dy: 0; property real fr: 0
        Rectangle {
            x: (stage.width - stage.w) / 2 + stage.dx; y: stage.y0 + stage.dy
            width: stage.w; height: stage.h
            radius: stage.fr > 0 ? Math.min(10 * stage.k, Math.min(width, height) / 2) : 6 * stage.k
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.9)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.3 + 0.5 * stage.fr)
            scale: stage.sc
            clip: true
            Column {
                x: 10 * stage.k; y: 10 * stage.k; spacing: 6 * stage.k
                opacity: stage.o
                Rectangle { width: 70 * stage.k; height: 6 * stage.k; radius: height / 2; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.5) }
                Rectangle { width: 46 * stage.k; height: 5 * stage.k; radius: height / 2; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25) }
                Rectangle { width: 96 * stage.k; height: 14 * stage.k; radius: 5 * stage.k; color: Appearance.colors.accent }
            }
        }
        function reset() { w = width; h = height; y0 = 0; o = 1; sc = 1; dx = 0; dy = 0; fr = 0 }
        SequentialAnimation {
            id: seq
            ScriptAction { script: { morphA.stop(); curtainA.stop(); zoomA.stop(); riseA.stop(); slideA.stop(); fadeA.stop(); stage.reset() } }
            ScriptAction { script: {
                const d = 10 * stage.k
                if (stage.style === "morph") { stage.w = d; stage.h = d; stage.y0 = -d; stage.o = 0; stage.fr = 1 }
                else if (stage.style === "curtain") { stage.h = 0; stage.fr = 1 }
                else if (stage.style === "zoom") { stage.sc = 0.85; stage.o = 0 }
                else if (stage.style === "rise") { stage.dy = 26 * stage.k; stage.o = 0 }
                else if (stage.style === "slide") { stage.dx = 36 * stage.k; stage.o = 0.25 }
                else if (stage.style === "fade") { stage.o = 0 }
            } }
            PauseAnimation { duration: 120 }
            ScriptAction { script: {
                if (stage.style === "morph") morphA.start()
                else if (stage.style === "curtain") curtainA.start()
                else if (stage.style === "zoom") zoomA.start()
                else if (stage.style === "rise") riseA.start()
                else if (stage.style === "slide") slideA.start()
                else if (stage.style === "fade") fadeA.start()
            } }
        }
        SequentialAnimation {
            id: morphA
            NumberAnimation { target: stage; property: "y0"; to: 0; duration: Appearance.dur(260); easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "w"; to: stage.width; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
            ParallelAnimation {
                NumberAnimation { target: stage; property: "h"; to: stage.height; duration: Appearance.dur(440); easing.type: Easing.OutBack }
                SequentialAnimation { PauseAnimation { duration: Appearance.dur(160) }
                                      NumberAnimation { target: stage; property: "o"; to: 1; duration: Appearance.dur(280) } }
            }
            NumberAnimation { target: stage; property: "fr"; to: 0; duration: Appearance.dur(220) }
        }
        SequentialAnimation {
            id: curtainA
            NumberAnimation { target: stage; property: "h"; to: stage.height; duration: Appearance.dur(520); easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "fr"; to: 0; duration: Appearance.dur(220) }
        }
        ParallelAnimation {
            id: zoomA
            NumberAnimation { target: stage; property: "sc"; to: 1; duration: Appearance.dur(380); easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            NumberAnimation { target: stage; property: "o"; to: 1; duration: Appearance.dur(260) }
        }
        ParallelAnimation {
            id: riseA
            NumberAnimation { target: stage; property: "dy"; to: 0; duration: Appearance.dur(380); easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "o"; to: 1; duration: Appearance.dur(300) }
        }
        ParallelAnimation {
            id: slideA
            NumberAnimation { target: stage; property: "dx"; to: 0; duration: Appearance.dur(280); easing.type: Easing.OutCubic }
            NumberAnimation { target: stage; property: "o"; to: 1; duration: Appearance.dur(240) }
        }
        NumberAnimation { id: fadeA; target: stage; property: "o"; to: 1; duration: Appearance.dur(320) }
    }
}
