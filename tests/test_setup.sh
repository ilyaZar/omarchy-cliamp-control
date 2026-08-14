#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_ROOT="$(mktemp -d)"
readonly TEST_DIR TEMP_ROOT
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

export HOME="$TEMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_BIN_HOME="$HOME/.local/bin"

mkdir -p "$XDG_CONFIG_HOME/omarchy"
printf '{"version":1,"sentinel":"preserve"}\n' \
  >"$XDG_CONFIG_HOME/omarchy/shell.json"

"$TEST_DIR/../setup.sh" >/dev/null
"$TEST_DIR/../setup.sh" >/dev/null
"$TEST_DIR/../setup_installation_management.sh" >/dev/null

desktop-file-validate \
  "$XDG_DATA_HOME/applications/io.github.ilyazar.cliamp.restore.desktop"
[[ -x $XDG_BIN_HOME/cliamp-widget ]]
[[ -f $XDG_DATA_HOME/icons/hicolor/scalable/apps/io.github.ilyazar.cliamp.svg ]]

"$TEST_DIR/../remove.sh" >/dev/null
[[ ! -e $XDG_BIN_HOME/cliamp-widget ]]
[[ ! -e $XDG_DATA_HOME/applications/io.github.ilyazar.cliamp.restore.desktop ]]
[[ ! -e $XDG_DATA_HOME/icons/hicolor/scalable/apps/io.github.ilyazar.cliamp.svg ]]
jq -e '.sentinel == "preserve"' \
  "$XDG_CONFIG_HOME/omarchy/shell.json" >/dev/null

"$TEST_DIR/../setup.sh" >/dev/null
printf '# user modification\n' >>"$XDG_BIN_HOME/cliamp-widget"
"$TEST_DIR/../remove.sh" >/dev/null
grep -q '^# user modification$' "$XDG_BIN_HOME/cliamp-widget"
[[ ! -e $XDG_DATA_HOME/applications/io.github.ilyazar.cliamp.restore.desktop ]]
[[ ! -e $XDG_DATA_HOME/icons/hicolor/scalable/apps/io.github.ilyazar.cliamp.svg ]]

printf 'ok - setup and clean removal\n'
