#!/bin/bash

set -euo pipefail

readonly PLUGIN_ID="io.github.ilyazar.cliamp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
readonly PLUGIN_TARGET="$CONFIG_HOME/omarchy/plugins/$PLUGIN_ID"

unlink_plugin=false
if [[ ${1:-} == "--unlink-plugin" ]]; then
  unlink_plugin=true
  shift
fi
if (( $# > 0 )); then
  printf 'usage: %s [--unlink-plugin]\n' "$0" >&2
  exit 2
fi

remove_owned_file() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [[ ! -e $target ]]; then
    printf '[ok] %s already absent\n' "$label"
  elif cmp -s "$source" "$target"; then
    rm -f -- "$target"
    printf '[ok] removed %s\n' "$label"
  else
    printf '[warn] preserved modified %s: %s\n' "$label" "$target"
  fi
}

remove_owned_file \
  "$SCRIPT_DIR/bin/cliamp-widget" \
  "$BIN_HOME/cliamp-widget" \
  "recovery command"
remove_owned_file \
  "$SCRIPT_DIR/share/applications/$PLUGIN_ID.restore.desktop" \
  "$DATA_HOME/applications/$PLUGIN_ID.restore.desktop" \
  "desktop entry"
remove_owned_file \
  "$SCRIPT_DIR/assets/winamp-logo.svg" \
  "$DATA_HOME/icons/hicolor/scalable/apps/$PLUGIN_ID.svg" \
  "launcher icon"

if [[ $unlink_plugin == true ]]; then
  if [[ -L $PLUGIN_TARGET ]] &&
    [[ $(readlink -f "$PLUGIN_TARGET") == "$SCRIPT_DIR" ]]; then
    rm -- "$PLUGIN_TARGET"
    printf '[ok] removed development plugin link\n'
  elif [[ -e $PLUGIN_TARGET || -L $PLUGIN_TARGET ]]; then
    printf '[warn] preserved plugin target not owned by this checkout: %s\n' \
      "$PLUGIN_TARGET"
  else
    printf '[ok] development plugin link already absent\n'
  fi
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
fi

printf '[info] shell settings and the CLIamp application were preserved\n'
