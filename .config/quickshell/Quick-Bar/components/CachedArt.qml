import QtQuick
import Quickshell.Io

// CachedArt — rend une image distante affichable sans requête HTTPS de Qt.
// Les URL http(s) sont téléchargées par curl dans /tmp puis exposées en file://
// (le chargement HTTPS direct par Qt fait planter Quickshell : crash OpenSSL
// dans QSslCertificate::fromFile). Les autres URL (file:, data:) passent telles
// quelles. `local` est vide tant que rien n'est prêt.
Item {
    id: root
    property string url: ""
    property string local: ""

    onUrlChanged: {
        if (!/^https?:/.test(url)) { local = url; return }
        const f = "/tmp/qs-art-" + Qt.md5(url) + ".jpg"
        proc.target = "file://" + f
        proc.command = ["sh", "-c", "[ -s \"$2\" ] || curl -sfL --max-time 10 -o \"$2\" \"$1\"", "_", url, f]
        proc.running = false
        proc.running = true
    }
    Process {
        id: proc
        property string target: ""
        onExited: (code) => root.local = code === 0 ? target : ""
    }
}
