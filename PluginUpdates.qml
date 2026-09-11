import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Mirrors omarchy.system-update, but for the git-managed shell plugins under
// ~/.config/omarchy/plugins/ instead of the OS/omarchy package itself. Those
// plugins are updated with `omarchy plugin update`, which only ever reports
// what's behind when asked interactively -- nothing surfaces it on its own.
BarWidget {
  id: root
  moduleName: "szalikdev.plugin-updates"

  property bool updateAvailable: false
  property string updateSummary: ""

  // Fetches each git-managed plugin's remote HEAD without merging (same fetch
  // omarchy-plugin-update performs) and lists any whose local HEAD has fallen
  // behind. Printed lines double as the tooltip body.
  readonly property string checkScript: [
    "export GIT_TERMINAL_PROMPT=0",
    "export GIT_SSH_COMMAND=\"ssh -oBatchMode=yes\"",
    "dir=\"$HOME/.config/omarchy/plugins\"",
    "updates=()",
    "if [[ -d \"$dir\" ]]; then",
    "  for d in \"$dir\"/*/; do",
    "    [[ -d \"$d/.git\" ]] || continue",
    "    id=$(basename \"$d\")",
    "    timeout 10 git -C \"$d\" fetch --quiet origin HEAD 2>/dev/null || continue",
    "    head=$(git -C \"$d\" rev-parse HEAD 2>/dev/null) || continue",
    "    fetch_head=$(git -C \"$d\" rev-parse FETCH_HEAD 2>/dev/null) || continue",
    "    [[ \"$head\" == \"$fetch_head\" ]] || updates+=(\"$id\")",
    "  done",
    "fi",
    "if (( ${#updates[@]} > 0 )); then printf '%s\\n' \"${updates[@]}\"; exit 0; else exit 1; fi"
  ].join("\n")

  function refresh() {
    if (!checkProc.running) checkProc.running = true
  }

  function runUpdate() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation 'omarchy plugin update; omarchy-shell -q szalikdev.plugin-updates refresh'")
  }

  visible: updateAvailable
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "szalikdev.plugin-updates"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: checkProc
    command: ["bash", "-c", root.checkScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const trimmed = (text || "").trim()
        root.updateAvailable = trimmed.length > 0
        root.updateSummary = trimmed
      }
    }
  }

  Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: root.updateSummary.length > 0
      ? "Plugin updates available:\n" + root.updateSummary
      : "Plugin updates available"
    onPressed: root.runUpdate()
  }
}
