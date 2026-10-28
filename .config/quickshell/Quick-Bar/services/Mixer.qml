pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Mixer — accès unique à l'audio PipeWire pour toutes les pages (Mixer, Game,
// Eq, panneau Spotify). Source de vérité pour : la sortie par défaut, les
// sorties disponibles, les flux de lecture des applications et leurs volumes.
//
//   Mixer.sink              sortie par défaut (nœud PipeWire)
//   Mixer.source            entrée par défaut (micro)
//   Mixer.outputs           sorties physiques/virtuelles (Scarlett, Easy Effects…)
//   Mixer.streams           flux de lecture (un par flux)
//   Mixer.apps              [{ label, nodes }] — flux regroupés par application
//   Mixer.streamsOf("spotify")   flux d'une application (nom en minuscules)
//   Mixer.setVolume(nodes, v) · toggleMute(nodes) · setOutput(node) · cycleOutput()
//
// Les propriétés d'un nœud (nom d'appli…) ne sont lisibles qu'une fois le nœud
// suivi par un PwObjectTracker : on suit donc tout, et on filtre ensuite.
QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    // Flux de LECTURE (isStream && isSink) ; les captures (cava, micros) sont exclues.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    property var _tracker: PwObjectTracker {
        objects: (root.sink ? [root.sink] : []).concat(root.source ? [root.source] : [], root.streams, root.outputs)
    }

    readonly property var apps: {
        const g = {}
        for (const n of streams) { const k = name(n); (g[k] = g[k] || []).push(n) }
        return Object.keys(g).map(k => ({ label: k, nodes: g[k] }))
    }

    function name(n) {
        const p = n.properties
        return (p && (p["application.name"] || p["media.name"])) || n.description || n.name || "App"
    }
    function icon(n) {
        const p = n.properties || {}
        const i = p["application.icon-name"] || DesktopEntries.heuristicLookup(p["application.name"] || "")?.icon
                  || (p["application.process.binary"] || "")
        return Quickshell.iconPath(i || "audio-volume-high", "audio-volume-high")
    }
    function deviceName(n) { return n.nickname || n.description || n.name || "—" }
    // Easy Effects Sink = chemin AVEC l'égaliseur ; une sortie directe le contourne.
    function isEq(n) { return (n.name || "").toLowerCase().indexOf("easyeffects") !== -1 }

    function streamsOf(appLower) {
        return streams.filter(n => ((n.properties || {})["application.name"] || "").toLowerCase() === appLower)
    }

    function setVolume(nodes, v) {
        v = Math.max(0, Math.min(1, v))
        for (const n of nodes) if (n?.audio) n.audio.volume = v
    }
    function toggleMute(nodes) {
        if (!nodes.length || !nodes[0]?.audio) return
        const m = !nodes[0].audio.muted
        for (const n of nodes) if (n?.audio) n.audio.muted = m
    }
    function setOutput(n) { Pipewire.preferredDefaultAudioSink = n }
    function cycleOutput() {
        const l = outputs
        if (l.length < 2) return
        let ci = 0
        for (let i = 0; i < l.length; i++) if (sink && l[i].name === sink.name) ci = i
        setOutput(l[(ci + 1) % l.length])
    }
}
