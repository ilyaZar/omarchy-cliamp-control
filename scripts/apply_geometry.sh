#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib/clients.sh
source "$SCRIPT_DIR/../lib/clients.sh"
# shellcheck source=lib/geometry.sh
source "$SCRIPT_DIR/../lib/geometry.sh"

alignment="${1:-}"
requested_width="${2:-}"
requested_height="${3:-}"

case "$alignment" in
  Left | Center | Right) ;;
  *)
    printf 'invalid alignment: %s\n' "$alignment" >&2
    exit 2
    ;;
esac

if [[ ! $requested_width =~ ^[1-9][0-9]*$ ]] ||
  [[ ! $requested_height =~ ^[1-9][0-9]*$ ]]; then
  printf 'width and height must be positive integers\n' >&2
  exit 2
fi

clients_json="$(hyprctl clients -j)"
monitors_json="$(hyprctl monitors -j)"
matched_clients="$(cliamp_managed_clients_json "$clients_json")"
client_count="$(jq -r 'length' <<<"$matched_clients")"
client_json="$(jq -c '.[0] // null' <<<"$matched_clients")"

geometry_json="$(
  cliamp_geometry_json \
    "$monitors_json" \
    "$client_json" \
    "$alignment" \
    "$requested_width" \
    "$requested_height"
)"
geometry_json="$(
  jq -c --argjson clientCount "$client_count" \
    '. + {clientCount: $clientCount}' <<<"$geometry_json"
)"

if [[ $client_json == "null" ]]; then
  if ! command -v cliamp >/dev/null 2>&1; then
    geometry_json="$(
      jq -c '.status = "unavailable"' <<<"$geometry_json"
    )"
  fi
  printf '%s\n' "$geometry_json"
  exit 0
fi

address="$(jq -r '.client.address' <<<"$geometry_json")"
if [[ ! $address =~ ^0x[0-9A-Fa-f]+$ ]]; then
  printf 'invalid CLIamp client address: %s\n' "$address" >&2
  exit 3
fi

IFS=$'\t' read -r x y width height < <(
  jq -r '[.actual.x, .actual.y, .actual.width, .actual.height] | @tsv' \
    <<<"$geometry_json"
)

dispatch_expression=""
if [[ $(jq -r '.floating == true' <<<"$client_json") != "true" ]]; then
  printf -v dispatch_expression \
    'hl.dispatch(hl.dsp.window.float({ action = "toggle", window = "address:%s" })); ' \
    "$address"
fi

printf -v geometry_expression \
  'hl.dispatch(hl.dsp.window.resize({ x = %d, y = %d, relative = false, window = "address:%s" })); hl.dispatch(hl.dsp.window.move({ x = %d, y = %d, relative = false, window = "address:%s" }))' \
  "$width" "$height" "$address" "$x" "$y" "$address"
dispatch_expression+="$geometry_expression"

hyprctl eval "$dispatch_expression" >/dev/null

observed_json="$(
  hyprctl clients -j | jq -c --arg address "$address" '
    [.[] | select(.address == $address)][0]
    | if . == null then null else {
        at: .at,
        size: .size,
        floating: .floating,
        workspace: .workspace.name
      } end
  '
)"

result_json="$(
  jq -cn \
    --argjson geometry "$geometry_json" \
    --argjson observed "$observed_json" '
      $geometry + {
        status: (if $observed == null then "vanished"
          elif $observed.floating == true
            and $observed.at == [$geometry.actual.x, $geometry.actual.y]
            and $observed.size == [$geometry.actual.width, $geometry.actual.height]
          then "applied"
          else "mismatch"
          end),
        observed: $observed
      }
    '
)"

printf '%s\n' "$result_json"

[[ $(jq -r '.status' <<<"$result_json") == "applied" ]]
