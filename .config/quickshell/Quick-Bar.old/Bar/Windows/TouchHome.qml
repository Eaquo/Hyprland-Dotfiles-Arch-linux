import QtQuick
import QtQuick.Layouts
import "../Common/"
import "../Components/"
import "../Services/home/"

// TouchHome — variante tactile (ultra-large) de la page Home du Dashboard.
//
// Réutilise les mêmes cartes que DashHome (ProfileCard, CalendarCard, ClockCard,
// PlayerCard, QuickSettings), réparties en 4 colonnes équilibrées pour 2560×720.
// Chaque carte est enveloppée dans un ScaledBox : son contenu est mis en page
// dans une boîte (taille/s) puis mis à l'échelle s → agrandit polices + éléments
// sans toucher au composant partagé (le popup Dashboard reste à l'échelle 1).
//
//  ┌──────────┬──────────┬───────────┬──────────────┐
//  │ Profile  │          │           │              │
//  ├──────────┤  Clock   │  Player   │ QuickSettings │
//  │ Calendar │          │           │              │
//  └──────────┴──────────┴───────────┴──────────────┘
Item {
    id: root
    readonly property int gap: 12

    // Zoom de contenu par carte (agrandit la police). Clock/Player déjà grands → 1.0.
    component ScaledBox: Item {
        id: sb
        property real s: 1.0
        default property alias content: holder.data
        Item {
            id: holder
            width:  sb.width  > 0 ? sb.width  / sb.s : 0
            height: sb.height > 0 ? sb.height / sb.s : 0
            transformOrigin: Item.TopLeft
            scale: sb.s
        }
    }

    RowLayout {
        id: rl
        anchors.fill: parent
        anchors.topMargin: root.gap
        spacing: root.gap

        // Largeur utile une fois les 3 gouttières retirées.
        readonly property real avail: width - root.gap * 3

        // ── 1. Profil + Calendrier ──────────────────────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: rl.avail * 0.22
            Layout.fillHeight: true
            spacing: root.gap

            ScaledBox {
                s: 1.4
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                ProfileCard {
                    anchors.fill: parent
                    avatarPath: "/home/florian/Eaquo_Assets/Edited Image.jpg"
                }
            }
            ScaledBox {
                s: 1.2
                Layout.fillWidth: true
                Layout.fillHeight: true
                CalendarCard { anchors.fill: parent }
            }
        }

        // ── 2. Horloge (déjà grande) ──────────────────────────────────────────────
        ClockCard {
            Layout.preferredWidth: rl.avail * 0.26
            Layout.fillHeight: true
        }

        // ── 3. Lecteur média (déjà grand) ─────────────────────────────────────────
        // Enveloppé dans un Item → PlayerCard se dimensionne via anchors.fill (comme
        // sur Dashboard/Grid), sinon la chaîne layer+MultiEffect de la pochette ne
        // s'affiche pas correctement avec un dimensionnement Layout.
        Item {
            Layout.preferredWidth: rl.avail * 0.28
            Layout.fillHeight: true
            PlayerCard { anchors.fill: parent }
        }

        // ── 4. Quick Settings ─────────────────────────────────────────────────────
        ScaledBox {
            s: 1.3
            Layout.preferredWidth: rl.avail * 0.24
            Layout.fillHeight: true
            QuickSettings { anchors.fill: parent }
        }
    }
}
