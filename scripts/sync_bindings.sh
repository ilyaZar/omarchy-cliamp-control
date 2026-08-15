#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PLUGIN_ROOT
readonly TOGGLE_SCRIPT="$PLUGIN_ROOT/scripts/toggle_cliamp.sh"
readonly CONFIG_FILE="${CLIAMP_HYPR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua}"

lua_quote() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '"%s"' "$value"
}

bindings_json="${CLIAMP_BINDINGS_JSON:-}"
if [[ -z $bindings_json ]]; then
  bindings_json="$(lua "$PLUGIN_ROOT/lib/scan_cliamp_bindings.lua" \
    "$CONFIG_FILE")"
fi

if ! jq -e 'type == "array"' >/dev/null <<<"$bindings_json"; then
  printf 'CLIamp binding discovery returned invalid JSON\n' >&2
  exit 2
fi

if [[ $(jq -r 'length' <<<"$bindings_json") -eq 0 ]]; then
  jq -cn '{status: "unbound", bindings: []}'
  exit 0
fi

toggle_lua="$(lua_quote "$TOGGLE_SCRIPT")"
expression=""
while IFS= read -r binding; do
  keys="$(jq -r '.keys' <<<"$binding")"
  description="$(jq -r '.description // ""' <<<"$binding")"
  [[ -n $description ]] || description="CLIamp drop-down"

  keys_lua="$(lua_quote "$keys")"
  description_lua="$(lua_quote "$description")"
  expression+="hl.unbind($keys_lua); "
  expression+="hl.bind($keys_lua, hl.dsp.exec_cmd($toggle_lua), "
  expression+="{ description = $description_lua }); "
done < <(jq -c '.[]' <<<"$bindings_json")

hyprctl eval "$expression" >/dev/null

jq -cn --argjson bindings "$bindings_json" '
  {
    status: "managed",
    bindings: ($bindings | map(
      . + {label: (.keys | gsub("[[:space:]]*\\+[[:space:]]*"; "+"))}
    ))
  }
'
