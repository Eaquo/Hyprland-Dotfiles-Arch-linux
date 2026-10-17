import QtQuick

// DashStats — page System du dashboard : les cartes de la barre, 3 colonnes défilantes (StatsBoard).
StatsBoard {
    columns: [["cpu", "tcpu"], ["ram", "tnvme", "net"], ["tgpu", "disk"]]
}
