import QtQuick

// TouchStats — page System du panneau tactile : les cartes de la barre, 4 colonnes (StatsBoard).
StatsBoard {
    columns: [["cpu"], ["ram", "net"], ["tcpu", "tgpu"], ["tnvme", "disk"]]
}
