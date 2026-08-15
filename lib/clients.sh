# shellcheck shell=bash

# Shared managed CLIamp client selection for runtime helpers.

CLIAMP_MANAGED_CLASS="org.omarchy.cliamp.quake"
CLIAMP_LEGACY_CLASS="org.omarchy.quake.music"
readonly CLIAMP_MANAGED_CLASS CLIAMP_LEGACY_CLASS

cliamp_managed_clients_json() {
  local clients_json="${1:-[]}"

  jq -c \
    --arg managed "$CLIAMP_MANAGED_CLASS" \
    --arg legacy "$CLIAMP_LEGACY_CLASS" '
      [
        .[]
        | select(
            .class == $managed
            or .initialClass == $managed
            or .class == $legacy
            or .initialClass == $legacy
          )
        | . + {
            _cliampRank: (
              if .class == $managed or .initialClass == $managed
              then 0 else 1 end
            )
          }
      ]
      | sort_by(._cliampRank)
      | map(del(._cliampRank))
    ' <<<"$clients_json"
}
