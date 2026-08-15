#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_ROOT="$(mktemp -d)"
readonly TEST_DIR TEMP_ROOT
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

readonly MOCK_BIN="$TEMP_ROOT/bin"
export CLIAMP_TEST_STATE="$TEMP_ROOT/state"
export CLIAMP_TEST_EXPRESSION="$TEMP_ROOT/expression"

mkdir -p "$MOCK_BIN" "$CLIAMP_TEST_STATE"

cat >"$MOCK_BIN/hyprctl" <<'MOCK'
#!/bin/bash
set -euo pipefail

case "${1:-}" in
  clients)
    if [[ -e $CLIAMP_TEST_STATE/applied ]]; then
      cat <<'JSON'
[
  {
    "address": "0xabc",
    "class": "org.omarchy.cliamp.quake",
    "initialClass": "org.omarchy.cliamp.quake",
    "monitor": 1,
    "workspace": {"name": "3"},
    "at": [360, 26],
    "size": [1200, 600],
    "floating": true
  }
]
JSON
    else
      cat <<'JSON'
[
  {
    "address": "0xabc",
    "class": "org.omarchy.cliamp.quake",
    "initialClass": "org.omarchy.cliamp.quake",
    "monitor": 1,
    "workspace": {"name": "3"},
    "at": [0, 0],
    "size": [800, 500],
    "floating": false
  },
  {
    "address": "0xdef",
    "class": "org.omarchy.quake.music",
    "initialClass": "org.omarchy.quake.music",
    "monitor": 1,
    "workspace": {"name": "special:music"},
    "floating": true
  },
  {
    "address": "0x123",
    "class": "unrelated",
    "initialClass": "unrelated",
    "monitor": 1,
    "workspace": {"name": "3"},
    "floating": false
  }
]
JSON
    fi
    ;;
  monitors)
    cat <<'JSON'
[
  {
    "id": 1,
    "name": "TEST",
    "width": 1920,
    "height": 1080,
    "x": 0,
    "y": 0,
    "scale": 1,
    "transform": 0,
    "reserved": [0, 26, 0, 0],
    "focused": true,
    "disabled": false
  }
]
JSON
    ;;
  eval)
    printf '%s\n' "${2:-}" >"$CLIAMP_TEST_EXPRESSION"
    touch "$CLIAMP_TEST_STATE/applied"
    ;;
  *)
    exit 2
    ;;
esac
MOCK
chmod 0755 "$MOCK_BIN/hyprctl"

result="$(
  PATH="$MOCK_BIN:$PATH" \
    bash "$TEST_DIR/../scripts/apply_geometry.sh" Center 1200 600
)"

jq -e '
  .status == "applied"
  and .clientCount == 1
  and .client.address == "0xabc"
  and .actual == {x: 360, y: 26, width: 1200, height: 600}
  and .observed.floating == true
' >/dev/null <<<"$result"
grep -Fq 'hl.dsp.window.float' "$CLIAMP_TEST_EXPRESSION"
grep -Fq 'hl.dsp.window.resize' "$CLIAMP_TEST_EXPRESSION"
grep -Fq 'hl.dsp.window.move' "$CLIAMP_TEST_EXPRESSION"

printf 'ok - managed client floats before geometry\n'
