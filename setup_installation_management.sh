#!/bin/bash

set -euo pipefail

readonly PLUGIN_ID="io.github.ilyazar.cliamp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

install_verify() {
  cmp -s "$SCRIPT_DIR/bin/cliamp-widget" "$BIN_HOME/cliamp-widget" ||
    return 1
  cmp -s \
    "$SCRIPT_DIR/share/applications/$PLUGIN_ID.restore.desktop" \
    "$DATA_HOME/applications/$PLUGIN_ID.restore.desktop" || return 1
  cmp -s \
    "$SCRIPT_DIR/assets/winamp-logo.svg" \
    "$DATA_HOME/icons/hicolor/scalable/apps/$PLUGIN_ID.svg" || return 1
  desktop-file-validate \
    "$DATA_HOME/applications/$PLUGIN_ID.restore.desktop" >/dev/null || return 1
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if install_verify; then
    printf '[ok] CLIamp widget integration is current\n'
  else
    printf '[error] CLIamp widget integration is missing or stale\n' >&2
    exit 1
  fi
fi
