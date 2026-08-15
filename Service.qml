import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: root

  property QtObject shell: null
  property string alignment: "Center"
  property int windowWidth: 1200
  property int windowHeight: 600
  property string lastStatus: "starting"
  property string lastError: ""
  property string lastSummary: "Starting geometry service"
  property var lastGeometry: null
  property bool rerunPending: false
  property int absentRetryCount: 0
  property string processOutput: ""
  property string processError: ""

  readonly property string applyScript: localPath(
    Qt.resolvedUrl("scripts/apply_geometry.sh"))

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    return decodeURIComponent(value)
  }

  function positiveInteger(value, fallback) {
    var parsed = Number(value)
    if (!isFinite(parsed) || parsed < 1 || parsed > 100000
        || Math.floor(parsed) !== parsed) return fallback
    return parsed
  }

  function validAlignment(value) {
    var text = String(value || "")
    return ["Left", "Center", "Right"].indexOf(text) >= 0
      ? text : "Center"
  }

  function configuredEntry() {
    var config = shell ? shell.shellConfig : null
    var layout = config && config.bar ? config.bar.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; layout && s < sections.length; s++) {
      var entries = layout[sections[s]]
      if (!Array.isArray(entries)) continue
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i]
        if (entry && String(entry.id || entry) === "io.github.ilyazar.cliamp")
          return typeof entry === "object" ? entry : { id: entry }
      }
    }
    return null
  }

  function refreshSettingsFromShell() {
    var entry = configuredEntry()
    if (!entry) return
    configure(
      validAlignment(entry.alignment),
      positiveInteger(entry.windowWidth, 1200),
      positiveInteger(entry.windowHeight, 600)
    )
  }

  function configure(nextAlignment, nextWidth, nextHeight) {
    var normalizedAlignment = validAlignment(nextAlignment)
    var normalizedWidth = positiveInteger(nextWidth, 1200)
    var normalizedHeight = positiveInteger(nextHeight, 600)
    var changed = alignment !== normalizedAlignment
      || windowWidth !== normalizedWidth
      || windowHeight !== normalizedHeight

    alignment = normalizedAlignment
    windowWidth = normalizedWidth
    windowHeight = normalizedHeight
    if (changed || lastStatus === "starting") scheduleApply(30)
  }

  function scheduleApply(delayMs) {
    applyTimer.interval = Math.max(20, Number(delayMs || 120))
    applyTimer.restart()
  }

  function applyGeometry() {
    if (applyProcess.running) {
      rerunPending = true
      return
    }
    processOutput = ""
    processError = ""
    applyProcess.command = [
      "bash",
      applyScript,
      alignment,
      String(windowWidth),
      String(windowHeight)
    ]
    applyProcess.running = true
  }

  function acceptResult(exitCode) {
    var parsed = null
    var raw = String(processOutput || "").trim()
    if (raw !== "") {
      try {
        parsed = JSON.parse(raw)
      } catch (error) {
        parsed = null
      }
    }

    if (parsed) {
      lastGeometry = parsed
      lastStatus = String(parsed.status || "error")
      if (lastStatus === "absent") {
        lastError = ""
        lastSummary = "Waiting for CLIamp"
      } else if (lastStatus === "unavailable") {
        lastError = "CLIamp is not installed"
        lastSummary = lastError
      } else if (lastStatus === "applied") {
        absentRetryCount = 0
        lastError = parsed.clientCount > 1
          ? "More than one CLIamp client exists" : ""
        lastSummary = parsed.actual.width + "x" + parsed.actual.height
          + " at " + parsed.actual.x + "," + parsed.actual.y
          + " on " + parsed.monitor.name
      } else {
        lastError = lastStatus === "mismatch"
          ? "Hyprland did not accept the exact geometry"
          : "CLIamp disappeared while geometry was applied"
        lastSummary = lastError
      }
    } else {
      lastStatus = "error"
      lastError = String(processError || "").trim()
        || "Geometry helper failed with exit " + exitCode
      lastSummary = lastError
    }

    if (rerunPending) {
      rerunPending = false
      scheduleApply(30)
    }
  }

  function eventName(event) {
    return String(event && event.name ? event.name : "").toLowerCase()
  }

  function handleHyprlandEvent(event) {
    var name = eventName(event)
    var relevant = [
      "openwindow",
      "closewindow",
      "movewindow",
      "movewindowv2",
      "changefloatingmode",
      "workspace",
      "workspacev2",
      "focusedmon",
      "activespecial",
      "activespecialv2",
      "monitoradded",
      "monitoraddedv2",
      "monitorremoved",
      "configreloaded"
    ]
    if (relevant.indexOf(name) >= 0) scheduleApply(120)
  }

  onShellChanged: refreshSettingsFromShell()

  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onShellConfigChanged() { root.refreshSettingsFromShell() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  Timer {
    id: applyTimer
    interval: 120
    onTriggered: root.applyGeometry()
  }

  Timer {
    interval: Math.min(15000, 2000 * Math.pow(2,
      Math.min(root.absentRetryCount, 3)))
    running: root.lastStatus === "absent"
      || root.lastStatus === "unavailable"
    repeat: true
    onTriggered: {
      root.absentRetryCount++
      root.scheduleApply(30)
    }
  }

  Process {
    id: applyProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processOutput = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processError = text
    }
    onExited: function(exitCode) { root.acceptResult(exitCode) }
  }

  Component.onCompleted: Qt.callLater(function() {
    root.refreshSettingsFromShell()
    root.scheduleApply(30)
  })
}
