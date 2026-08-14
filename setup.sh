#!/bin/bash

set -euo pipefail

readonly PLUGIN_ID="io.github.ilyazar.cliamp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
readonly COMMAND_TARGET="$BIN_HOME/cliamp-widget"
readonly DESKTOP_TARGET="$DATA_HOME/applications/$PLUGIN_ID.restore.desktop"
readonly ICON_TARGET="$DATA_HOME/icons/hicolor/scalable/apps/$PLUGIN_ID.svg"
readonly PLUGIN_TARGET="$CONFIG_HOME/omarchy/plugins/$PLUGIN_ID"

link_plugin=false
if [[ ${1:-} == "--link-plugin" ]]; then
  link_plugin=true
  shift
fi
if (( $# > 0 )); then
  printf 'usage: %s [--link-plugin]\n' "$0" >&2
  exit 2
fi

printf 'CLIamp widget setup\n'
printf 'source: %s\n' "$SCRIPT_DIR"
printf 'command: %s\n' "$COMMAND_TARGET"
printf 'desktop entry: %s\n' "$DESKTOP_TARGET"
printf 'icon: %s\n' "$ICON_TARGET"

install -Dm755 "$SCRIPT_DIR/bin/cliamp-widget" "$COMMAND_TARGET"
install -Dm644 \
  "$SCRIPT_DIR/share/applications/$PLUGIN_ID.restore.desktop" \
  "$DESKTOP_TARGET"
install -Dm644 "$SCRIPT_DIR/assets/winamp-logo.svg" "$ICON_TARGET"

printf '[ok] installed recovery command\n'
printf '[ok] installed application launcher entry\n'
printf '[ok] installed launcher icon\n'

if [[ $link_plugin == true ]]; then
  mkdir -p "$(dirname "$PLUGIN_TARGET")"
  if [[ -e $PLUGIN_TARGET || -L $PLUGIN_TARGET ]]; then
    if [[ $(readlink -f "$PLUGIN_TARGET") != "$SCRIPT_DIR" ]]; then
      printf '[error] plugin target already belongs to another checkout: %s\n' \
        "$PLUGIN_TARGET" >&2
      exit 1
    fi
    printf '[ok] development plugin link is current\n'
  else
    ln -s "$SCRIPT_DIR" "$PLUGIN_TARGET"
    printf '[ok] linked development plugin checkout\n'
  fi

  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell -q shell rescanPlugins >/dev/null 2>&1 || true
  fi
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
fi

printf '[info] enable deliberately with: omarchy plugin enable %s\n' \
  "$PLUGIN_ID"
printf '[info] verify with: %s/setup_installation_management.sh\n' \
  "$SCRIPT_DIR"
