# shellcheck shell=bash

# Shared managed CLIamp client selection for runtime helpers.

CLIAMP_MANAGED_CLASS="org.omarchy.cliamp.quake"
readonly CLIAMP_MANAGED_CLASS

cliamp_managed_clients_json() {
  local clients_json="${1:-[]}"

  jq -c \
    --arg managed "$CLIAMP_MANAGED_CLASS" '
      [
        .[]
        | select(
            .class == $managed
            or .initialClass == $managed
          )
      ]
    ' <<<"$clients_json"
}
