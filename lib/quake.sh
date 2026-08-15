# shellcheck shell=bash

# Generic special-workspace drop-down mechanics.

quake_special_workspace_visible() {
  local workspace="$1"

  hyprctl monitors -j | jq -e --arg workspace "special:$workspace" '
    any(.[]; .specialWorkspace.name == $workspace)
  ' >/dev/null
}

quake_move_to_special_workspace() {
  local workspace="$1"
  local address="$2"

  hyprctl dispatch \
    "hl.dsp.window.move({ workspace = \"special:$workspace\", follow = false, window = \"address:$address\" })" \
    >/dev/null
}

quake_toggle_special_workspace() {
  local workspace="$1"

  hyprctl dispatch \
    "hl.dsp.workspace.toggle_special(\"$workspace\")" \
    >/dev/null
}

quake_toggle_client() {
  local client_json="$1"
  local workspace="$2"
  local address current_workspace target_workspace

  address="$(jq -r '.address' <<<"$client_json")"
  [[ $address =~ ^0x[0-9A-Fa-f]+$ ]] || return 2

  target_workspace="special:$workspace"
  current_workspace="$(jq -r '.workspace.name // ""' <<<"$client_json")"

  if [[ $current_workspace != "$target_workspace" ]]; then
    quake_move_to_special_workspace "$workspace" "$address"
    if ! quake_special_workspace_visible "$workspace"; then
      quake_toggle_special_workspace "$workspace"
    fi
  else
    quake_toggle_special_workspace "$workspace"
  fi
}
