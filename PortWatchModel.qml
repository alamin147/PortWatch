import QtQuick
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var ports: []
    property bool panelOpen: false

    property string armedKey: ""
    property int armedPid: 0
    property string armedStartTime: ""
    property string busyKey: ""
    property string errorKey: ""
    property string errorText: ""

    readonly property var ownPorts: ports.filter(function(p) {
        return p.pid > 0 && !p.isApp
    })
    readonly property var appPorts: ports.filter(function(p) {
        return p.pid > 0 && p.isApp
    })
    readonly property var systemPorts: ports.filter(function(p) {
        return p.pid === 0
    })

    readonly property int totalPorts: ownPorts.length + appPorts.length + systemPorts.length
    readonly property string summaryText: totalPorts === 0
        ? "No listening ports"
        : totalPorts + (totalPorts === 1 ? " port detected" : " ports detected")

    readonly property int maxRows: 200

    function keyFor(p) {
        return p.proto + ":" + p.port + ":" + p.pid
    }

    function refresh() {
        if (!scanProc.running)
            scanProc.running = true
    }

    function clearArmed() {
        root.armedKey = ""
        root.armedPid = 0
        root.armedStartTime = ""
    }

    function requestKill(p) {
        const key = keyFor(p)

        if (killProc.running)
            return

        // Only show Confirm after we have a stable, verifiable target.
        if (root.armedKey !== key) {
            if (!p.startTime || p.pid <= 0) {
                root.errorKey = key
                root.errorText = "Couldn't verify process; refresh"
                errorTimer.restart()
                root.refresh()
                return
            }

            root.armedKey = key
            root.armedPid = p.pid
            root.armedStartTime = String(p.startTime)
            armTimer.restart()
            return
        }

        // Confirm always acts on the exact PID/start-time captured on the first
        // click. This stays stable even if the 3-second refresh rebuilds the
        // Repeater delegates between Kill and Confirm.
        const targetPid = root.armedPid
        const targetStartTime = root.armedStartTime

        armTimer.stop()
        root.clearArmed()

        if (targetPid <= 0 || !targetStartTime) {
            root.errorKey = key
            root.errorText = "Confirmation expired; try again"
            errorTimer.restart()
            return
        }

        root.busyKey = key
        killProc.targetKey = key
        killProc.command = [
            "bash", "-c", root.killScript,
            "portwatch-kill", String(targetPid), String(targetStartTime)
        ]
        killProc.running = true
    }

    readonly property string scanScript: [
        "{",
        "ports=$(timeout -s KILL 5 ss -H -tulpn 2>/dev/null | head -n 500)",
        "printf '%s\\n' \"$ports\"",
        "echo '===WIN==='",
        "timeout -s KILL 5 hyprctl clients -j 2>/dev/null",
        "echo '===PROC==='",
        "for pid in $(printf '%s\\n' \"$ports\" | grep -oP 'pid=\\K[0-9]+' | sort -u | head -n 300); do",
        "  cmd=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\\0' ' ' | head -c 200)",
        "  cwd=$(readlink -f /proc/$pid/cwd 2>/dev/null | head -c 200)",
        "  st=$(cat /proc/$pid/stat 2>/dev/null)",
        "  st=${st##*') '}",
        "  start=$(printf '%s' \"$st\" | cut -d' ' -f20)",
        "  echo \"$pid<|>$start<|>$cwd<|>$cmd\"",
        "done",
        "} | head -c 1000000"
    ].join("\n")

    readonly property string killScript: [
        "p=$1",
        "want=$2",
        "s=$(cat /proc/$p/stat 2>/dev/null) || exit 3",
        "s=${s##*') '}",
        "got=$(printf '%s' \"$s\" | cut -d' ' -f20)",
        "[ -n \"$got\" ] || exit 3",
        "[ \"$got\" = \"$want\" ] || exit 4",
        "kill -TERM \"$p\""
    ].join("\n")

    function parseWindowInfo(jsonText) {
        const map = ({})
        try {
            const clients = JSON.parse(jsonText || "[]")
            for (let i = 0; i < clients.length; i++) {
                const c = clients[i]
                if (c && c.pid && !(c.pid in map))
                    map[c.pid] = { klass: c.class || "" }
            }
        } catch (e) {
            console.warn("PortWatch: failed to parse hyprctl output:", e)
        }
        return map
    }

    function parseProcInfo(procText) {
        const map = ({})
        const lines = procText.split("\n")

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (!line)
                continue

            const parts = line.split("<|>")
            if (parts.length < 4)
                continue

            map[parts[0]] = {
                start: parts[1],
                cwd: parts[2],
                cmd: parts.slice(3).join("<|>")
            }
        }

        return map
    }

    function clamp(str, n) {
        const value = String(str || "")
        return value.length > n ? value.slice(0, n) + "…" : value
    }

    function buildLabel(processName, pid, win) {
        if (win)
            return root.clamp(win.klass || processName || "app", 64) + " · pid " + pid

        return processName
            ? root.clamp(processName, 64) + " · pid " + pid
            : "unknown process"
    }

    function buildDetail(proc) {
        if (!proc || !proc.cwd)
            return ""

        const parts = proc.cwd.split("/").filter(function(s) {
            return s.length > 0
        })
        const base = root.clamp(parts.length ? parts[parts.length - 1] : proc.cwd, 40)
        const cmd = root.clamp((proc.cmd || "").trim().replace(/\s+/g, " "), 48)

        return cmd ? base + " — " + cmd : ""
    }

    function parsePorts(text, windowInfo, procInfo) {
        const lines = text.split("\n")
        const seen = ({})
        const out = []

        for (let i = 0; i < lines.length && out.length < root.maxRows; i++) {
            const line = lines[i].trim()
            if (!line)
                continue

            const match = line.match(/^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s*(.*)$/)
            if (!match)
                continue

            const proto = match[1]
            const state = match[2]
            const local = match[5]
            const rest = match[7] || ""

            if (proto === "tcp" && state !== "LISTEN")
                continue
            if (proto !== "tcp" && proto !== "udp")
                continue

            const portMatch = local.match(/:(\d+)$/)
            if (!portMatch)
                continue

            const port = parseInt(portMatch[1], 10)
            const address = local.slice(0, local.length - portMatch[0].length) || "*"

            const procMatch = rest.match(/\("([^"]+)",pid=(\d+)/)
            const processName = procMatch ? procMatch[1].replace(/-MainThread$/, "") : ""
            const pid = procMatch ? parseInt(procMatch[2], 10) : 0

            const key = proto + ":" + port + ":" + pid
            if (seen[key])
                continue
            seen[key] = true

            const win = pid > 0 ? windowInfo[pid] : undefined
            const proc = pid > 0 ? procInfo[pid] : undefined

            out.push({
                proto: proto,
                port: port,
                address: address,
                process: processName,
                pid: pid,
                startTime: proc ? (proc.start || "") : "",
                isApp: !!win,
                label: root.buildLabel(processName, pid, win),
                detail: root.buildDetail(proc)
            })
        }

        out.sort(function(a, b) {
            return a.port - b.port
        })

        return out
    }

    Timer {
        id: scanWatchdog
        interval: 10000
        onTriggered: {
            if (scanProc.running)
                scanProc.running = false
        }
    }

    Process {
        id: scanProc

        command: ["bash", "-c", root.scanScript]

        onRunningChanged: {
            if (running)
                scanWatchdog.restart()
            else
                scanWatchdog.stop()
        }

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                const winMarker = "\n===WIN===\n"
                const procMarker = "\n===PROC===\n"

                const winIdx = text.indexOf(winMarker)
                const procIdx = text.indexOf(procMarker)

                const ssText = winIdx >= 0 ? text.slice(0, winIdx) : text
                const winText = (winIdx >= 0 && procIdx >= 0)
                    ? text.slice(winIdx + winMarker.length, procIdx)
                    : ""
                const procText = procIdx >= 0
                    ? text.slice(procIdx + procMarker.length)
                    : ""

                const windowInfo = root.parseWindowInfo(winText)
                const procInfo = root.parseProcInfo(procText)

                root.ports = root.parsePorts(ssText, windowInfo, procInfo)
            }
        }
    }

    Timer {
        id: killWatchdog
        interval: 5000
        onTriggered: {
            if (killProc.running)
                killProc.running = false
        }
    }

    Process {
        id: killProc

        property string targetKey: ""

        onRunningChanged: {
            if (running)
                killWatchdog.restart()
            else
                killWatchdog.stop()
        }

        onExited: function(exitCode) {
            root.busyKey = ""

            if (exitCode !== 0) {
                root.errorKey = targetKey
                root.errorText = exitCode === 3
                    ? "Already gone"
                    : exitCode === 4
                        ? "Process changed; refreshed"
                        : "Couldn't stop it (permission?)"
                errorTimer.restart()
            }

            root.refresh()
        }
    }

    Timer {
        id: armTimer
        interval: 5000
        onTriggered: root.clearArmed()
    }

    Timer {
        id: errorTimer
        interval: 3500
        onTriggered: {
            root.errorKey = ""
            root.errorText = ""
        }
    }

    // Only scan every 3 seconds while the popout is actually visible.
    Timer {
        interval: 3000
        repeat: true
        running: root.panelOpen
        onTriggered: root.refresh()
    }

    onPanelOpenChanged: {
        if (panelOpen)
            refresh()
    }

    Component.onCompleted: refresh()
}
