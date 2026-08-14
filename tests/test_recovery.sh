#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_ROOT="$(mktemp -d)"
readonly TEST_DIR TEMP_ROOT
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

mkdir -p "$TEMP_ROOT/bin" "$TEMP_ROOT/config/omarchy"
touch "$TEMP_ROOT/calls"

cat >"$TEMP_ROOT/bin/omarchy-shell" <<'FAKE'
#!/bin/bash
printf 'omarchy-shell %s\n' "$*" >>"$CLIAMP_TEST_CALLS"
FAKE

cat >"$TEMP_ROOT/bin/omarchy" <<'FAKE'
#!/bin/bash
printf 'omarchy %s\n' "$*" >>"$CLIAMP_TEST_CALLS"
if [[ $* == "plugin list --json" ]]; then
  printf '[{"id":"io.github.ilyazar.cliamp","enabled":true}]\n'
fi
FAKE
chmod +x "$TEMP_ROOT/bin/omarchy-shell" "$TEMP_ROOT/bin/omarchy"

cat >"$TEMP_ROOT/config/omarchy/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [],
      "center": [],
      "right": [
        {
          "id": "io.github.ilyazar.cliamp",
          "iconVisible": true
        }
      ]
    }
  },
  "plugins": []
}
JSON

export CLIAMP_TEST_CALLS="$TEMP_ROOT/calls"
export PATH="$TEMP_ROOT/bin:$PATH"
export XDG_CONFIG_HOME="$TEMP_ROOT/config"

"$TEST_DIR/../bin/cliamp-widget" >/dev/null
"$TEST_DIR/../bin/cliamp-widget" show >/dev/null

[[ $(grep -c '^omarchy-shell shell rescanPlugins$' "$TEMP_ROOT/calls") -eq 2 ]]
[[ $(grep -c '^omarchy bar put io.github.ilyazar.cliamp$' "$TEMP_ROOT/calls") -eq 2 ]]
[[ $(grep -c '^omarchy bar set io.github.ilyazar.cliamp iconVisible true --json$' \
  "$TEMP_ROOT/calls") -eq 2 ]]

status_output="$("$TEST_DIR/../bin/cliamp-widget" status)"
grep -q '^service: enabled$' <<<"$status_output"
grep -q '^bar: visible (right)$' <<<"$status_output"

hidden_config="$TEMP_ROOT/config/omarchy/shell.hidden.json"
jq '(.bar.layout.right[0].iconVisible) = false' \
  "$TEMP_ROOT/config/omarchy/shell.json" >"$hidden_config"
mv "$hidden_config" "$TEMP_ROOT/config/omarchy/shell.json"
status_output="$("$TEST_DIR/../bin/cliamp-widget" status)"
grep -q '^bar: hidden (right)$' <<<"$status_output"

"$TEST_DIR/../bin/cliamp-widget" hide >/dev/null
grep -q '^omarchy bar set io.github.ilyazar.cliamp iconVisible false --json$' \
  "$TEMP_ROOT/calls"

printf 'ok - recovery command\n'
