#!/bin/bash

# Pure geometry calculation shared by the runtime helper and tests.

cliamp_geometry_json() {
  local monitors_json="$1"
  local client_json="$2"
  local alignment="$3"
  local requested_width="$4"
  local requested_height="$5"

  jq -cen \
    --argjson monitors "$monitors_json" \
    --argjson client "$client_json" \
    --arg alignment "$alignment" \
    --argjson requestedWidth "$requested_width" \
    --argjson requestedHeight "$requested_height" '
      def number_or($fallback):
        if type == "number" then . else $fallback end;
      def clamp($minimum; $maximum):
        if . < $minimum then $minimum
        elif . > $maximum then $maximum
        else .
        end;

      ($monitors | map(select(.disabled != true))) as $activeMonitors
      | (if $client == null then
           ($activeMonitors | map(select(.focused == true))[0])
         else
           ($activeMonitors
             | map(select((.id | tonumber) == ($client.monitor | tonumber)))[0])
         end) as $monitor
      | if $monitor == null then
          error(if $client == null then
            "active monitor not found"
          else
            "client monitor not found"
          end)
        else . end
      | ($monitor.scale | number_or(1)) as $scale
      | if $scale <= 0 then error("monitor scale must be positive") else . end
      | ($monitor.transform | number_or(0) | floor) as $transform
      | ($monitor.width | number_or(0)) as $pixelWidth
      | ($monitor.height | number_or(0)) as $pixelHeight
      | (if ($transform % 2) == 1 then $pixelHeight else $pixelWidth end
          / $scale | floor) as $logicalWidth
      | (if ($transform % 2) == 1 then $pixelWidth else $pixelHeight end
          / $scale | floor) as $logicalHeight
      | ($monitor.reserved // [0, 0, 0, 0]) as $reserved
      | ($reserved[0] | number_or(0) | floor | if . < 0 then 0 else . end)
          as $reservedLeft
      | ($reserved[1] | number_or(0) | floor | if . < 0 then 0 else . end)
          as $reservedTop
      | ($reserved[2] | number_or(0) | floor | if . < 0 then 0 else . end)
          as $reservedRight
      | ($reserved[3] | number_or(0) | floor | if . < 0 then 0 else . end)
          as $reservedBottom
      | ([1, $logicalWidth - $reservedLeft - $reservedRight] | max | floor)
          as $usableWidth
      | ([1, $logicalHeight - $reservedTop - $reservedBottom] | max | floor)
          as $usableHeight
      | ($requestedWidth | floor | clamp(1; $usableWidth)) as $width
      | ($requestedHeight | floor | clamp(1; $usableHeight)) as $height
      | (($monitor.x | number_or(0) | floor) + $reservedLeft) as $usableX
      | (($monitor.y | number_or(0) | floor) + $reservedTop) as $usableY
      | (if $alignment == "Left" then $usableX
         elif $alignment == "Center" then
           $usableX + (($usableWidth - $width) / 2 | floor)
         elif $alignment == "Right" then
           $usableX + $usableWidth - $width
         else error("invalid alignment")
         end) as $x
      | {
          status: (if $client == null then "absent" else "calculated" end),
          clientPresent: ($client != null),
          client: (if $client == null then null else {
            address: $client.address,
            monitor: $client.monitor,
            workspace: $client.workspace.name
          } end),
          monitor: {
            id: $monitor.id,
            name: $monitor.name,
            x: ($monitor.x | floor),
            y: ($monitor.y | floor),
            logicalWidth: $logicalWidth,
            logicalHeight: $logicalHeight,
            scale: $scale,
            transform: $transform,
            reserved: [
              $reservedLeft,
              $reservedTop,
              $reservedRight,
              $reservedBottom
            ]
          },
          usable: {
            x: $usableX,
            y: $usableY,
            width: $usableWidth,
            height: $usableHeight
          },
          requested: {
            alignment: $alignment,
            width: $requestedWidth,
            height: $requestedHeight
          },
          actual: {
            x: $x,
            y: $usableY,
            width: $width,
            height: $height
          }
        }
    '
}
