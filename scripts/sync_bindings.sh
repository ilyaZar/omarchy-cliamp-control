#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PLUGIN_ROOT
readonly TOGGLE_SCRIPT="$PLUGIN_ROOT/scripts/toggle_cliamp.sh"
readonly CONFIG_FILE="${CLIAMP_HYPR_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua}"
readonly -a BINDING_BOOLEAN_OPTIONS=(
  mouse
  repeating
  locked
  release
  non_consuming
  transparent
  ignore_mods
  dont_inhibit
  long_press
  submap_universal
  click
  drag
  allow_input_capture
)

lua_quote() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '"%s"' "$value"
}

binding_options_lua() {
  local binding_json="$1"
  local description="$2"
  local description_lua option option_value
  local result separator

  description_lua="$(lua_quote "$description")"
  result="{ description = $description_lua"
  separator=", "

  for option in "${BINDING_BOOLEAN_OPTIONS[@]}"; do
    option_value="$(
      jq -r --arg option "$option" '
        if (.options | type) == "object"
            and (.options[$option] | type) == "boolean"
        then (.options[$option] | tostring)
        else empty
        end
      ' <<<"$binding_json"
    )"
    if [[ -n $option_value ]]; then
      result+="$separator$option = $option_value"
    fi
  done

  local device_json device_result device_separator inclusive list_present
  device_json="$(
    jq -c '
      if (.options.device | type) == "object"
      then .options.device
      else null
      end
    ' <<<"$binding_json"
  )"
  if [[ $device_json != "null" ]]; then
    device_result="{ "
    device_separator=""
    inclusive="$(
      jq -r '
        if (.inclusive | type) == "boolean"
        then (.inclusive | tostring)
        else empty
        end
      ' <<<"$device_json"
    )"
    if [[ -n $inclusive ]]; then
      device_result+="inclusive = $inclusive"
      device_separator=", "
    fi

    list_present="$(jq -r '(.list | type) == "array"' <<<"$device_json")"
    if [[ $list_present == "true" ]]; then
      local device_value device_value_lua
      local list_result="{ "
      local list_separator=""
      while IFS= read -r device_value; do
        device_value_lua="$(lua_quote "$device_value")"
        list_result+="$list_separator$device_value_lua"
        list_separator=", "
      done < <(jq -r '.list[] | select(type == "string")' <<<"$device_json")
      list_result+=" }"
      device_result+="$device_separator"'list = '"$list_result"
    fi
    device_result+=" }"
    result+="$separator"'device = '"$device_result"
  fi

  printf '%s }' "$result"
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
  options_lua="$(binding_options_lua "$binding" "$description")"
  expression+="hl.unbind($keys_lua); "
  expression+="hl.bind($keys_lua, hl.dsp.exec_cmd($toggle_lua), "
  expression+="$options_lua); "
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
