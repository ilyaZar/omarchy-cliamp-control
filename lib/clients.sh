# shellcheck shell=bash

# Shared CLIamp client selection for runtime helpers.

CLIAMP_STOCK_CLASS="org.omarchy.cliamp"
CLIAMP_LEGACY_CLASS="org.omarchy.quake.music"
readonly CLIAMP_STOCK_CLASS CLIAMP_LEGACY_CLASS

cliamp_supported_clients_json() {
  local clients_json="${1:-[]}"

  jq -c \
    --arg stock "$CLIAMP_STOCK_CLASS" \
    --arg legacy "$CLIAMP_LEGACY_CLASS" '
      [
        .[]
        | select(
            .class == $stock
            or .initialClass == $stock
            or .class == $legacy
            or .initialClass == $legacy
          )
        | . + {
            _cliampRank: (
              if .class == $stock or .initialClass == $stock then 0 else 1 end
            )
          }
      ]
      | sort_by(._cliampRank)
      | map(del(._cliampRank))
    ' <<<"$clients_json"
}
