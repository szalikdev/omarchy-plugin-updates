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
  // behind. Printed lines double as the tooltip body (capped, see maxReport).
  //
  // This runs unattended on a timer, against directories that hold whatever
  // git config a plugin author (or a later compromise of one) put there, so it
  // is held to a higher bar than a command a person types themselves:
  //  - Every executable is an absolute path (/usr/bin/*, guaranteed by Arch's
  //    merged-usr layout, which Omarchy depends on elsewhere too), never a
  //    bare name resolved through ambient PATH.
  //  - Every git call is a fetch/rev-parse only -- nothing here ever checks
  //    out or merges, so blob-level filters (clean/smudge) never run.
  //  - Every git call still passes -c overrides that beat anything the
  //    repo's own .git/config (or an include it pulls in) sets: no credential
  //    helper, no fsmonitor hook, no hooksPath, no gitProxy/http.proxy, and no
  //    ext:// or file:// transport (the classic config-driven RCE/exfil
  //    vectors). GIT_SSH_COMMAND is set via env, which outranks any
  //    repo-local core.sshCommand.
  //  - Repos scanned per run, and the whole operation, are bounded, and the
  //    outer Process itself carries a hard wall-clock cap so a stuck fetch or
  //    a directory full of repos can't hang this indefinitely.
  readonly property int maxRepos: 50
  readonly property int maxReport: 20
  readonly property string checkScript: [
    "export GIT_TERMINAL_PROMPT=0",
    "export GIT_SSH_COMMAND=\"/usr/bin/ssh -oBatchMode=yes\"",
    "dir=\"$HOME/.config/omarchy/plugins\"",
    "updates=()",
    "count=0",
    "safe_git=(/usr/bin/git" +
      " -c protocol.ext.allow=never -c protocol.file.allow=never" +
      " -c credential.helper= -c core.fsmonitor=false" +
      " -c core.hooksPath=/dev/null -c core.gitProxy= -c http.proxy=)",
    "if [[ -d \"$dir\" ]]; then",
    "  for d in \"$dir\"/*/; do",
    "    (( count >= " + maxRepos + " )) && break",
    "    [[ -d \"$d/.git\" ]] || continue",
    "    count=$((count + 1))",
    "    id=${d%/}; id=${id##*/}",
    "    /usr/bin/timeout 10 \"${safe_git[@]}\" -C \"$d\" fetch --quiet origin HEAD 2>/dev/null || continue",
    "    head=$(/usr/bin/timeout 5 \"${safe_git[@]}\" -C \"$d\" rev-parse HEAD 2>/dev/null) || continue",
    "    fetch_head=$(/usr/bin/timeout 5 \"${safe_git[@]}\" -C \"$d\" rev-parse FETCH_HEAD 2>/dev/null) || continue",
    "    [[ \"$head\" == \"$fetch_head\" ]] || updates+=(\"$id\")",
    "  done",
    "fi",
    "if (( ${#updates[@]} > 0 )); then printf '%s\\n' \"${updates[@]:0:" + maxReport + "}\"; exit 0; else exit 1; fi"
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
    // The outer timeout bounds the whole scan wall-clock-wise even though
    // every git call inside already carries its own timeout, in case a stuck
    // subprocess or an unexpectedly large plugin directory adds up.
    command: ["/usr/bin/timeout", "90", "/usr/bin/bash", "-c", root.checkScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let trimmed = (text || "").trim()
        if (trimmed.length > 2000) trimmed = trimmed.slice(0, 2000) + "\n…"
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
