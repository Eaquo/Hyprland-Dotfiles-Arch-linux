import QtQuick
import "." as T

// Input — une saisie libre (recherche web, calcul…). Entrée renvoie le texte tapé ;
// avec --live (LIVE dans un script), la sortie de la commande s'affiche dessous et Entrée renvoie la ligne choisie.
T.List {
    prefW: 700
    rows: 6
    hints: menu.req.live ? "↑↓ choisir un résultat  ·  entrée valider" : "entrée valider"
}
