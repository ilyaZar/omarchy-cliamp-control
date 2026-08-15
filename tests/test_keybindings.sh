#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_ROOT="$(mktemp -d)"
readonly TEST_DIR TEMP_ROOT
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

export HOME="$TEMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export CAPTURE_FILE="$TEMP_ROOT/editor-args"

readonly BINDINGS_FILE="$XDG_CONFIG_HOME/hypr/bindings.lua"
readonly MOCK_BIN="$TEMP_ROOT/bin"
readonly EDITOR_STATE="$XDG_STATE_HOME/omarchy/defaults/editor"

mkdir -p "$(dirname "$BINDINGS_FILE")" "$(dirname "$EDITOR_STATE")" \
  "$MOCK_BIN"
printf '%s\n' \
  '-- Personal application bindings' \
  'o.bind("SUPER + A", "Browser", { omarchy = "browser" })' \
  'o.bind(' \
  '  "SUPER + SHIFT + ALT + M",' \
  '  "My renamed player",' \
  '  { tui = "cliamp", focus = true }' \
  ')' >"$BINDINGS_FILE"
printf 'nvim\n' >"$EDITOR_STATE"

printf '%s\n' \
  '#!/bin/bash' \
  "printf '%s\\n' \"\$@\" >\"\$CAPTURE_FILE\"" \
  >"$MOCK_BIN/omarchy-launch-editor"
printf '%s\n' '#!/bin/bash' 'exit 0' \
  >"$MOCK_BIN/omarchy-notification-send"
chmod 0755 "$MOCK_BIN/omarchy-launch-editor" \
  "$MOCK_BIN/omarchy-notification-send"

PATH="$MOCK_BIN:$PATH" "$TEST_DIR/../open-keybindings.sh"
mapfile -t editor_args <"$CAPTURE_FILE"

[[ ${editor_args[0]} == "+3" ]]
[[ ${editor_args[1]} == "+normal! zz" ]]
[[ ${editor_args[2]} == "$BINDINGS_FILE" ]]

printf '%s\n' \
  '-- Personal application bindings' \
  'o.bind("F10", "Another name", { tui = "cliamp", focus = true })' \
  >"$BINDINGS_FILE"

PATH="$MOCK_BIN:$PATH" "$TEST_DIR/../open-keybindings.sh"
mapfile -t editor_args <"$CAPTURE_FILE"

[[ ${editor_args[0]} == "+2" ]]
[[ ${editor_args[1]} == "+normal! zz" ]]
[[ ${editor_args[2]} == "$BINDINGS_FILE" ]]

printf 'ok - renamed table-form keybinding editor target\n'
