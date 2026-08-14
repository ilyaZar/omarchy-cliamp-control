#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR

# shellcheck source=lib/geometry.sh
source "$TEST_DIR/../lib/geometry.sh"

assert_json() {
  local json="$1"
  local expression="$2"
  local label="$3"

  if ! jq -e "$expression" >/dev/null <<<"$json"; then
    printf 'not ok - %s\n%s\n' "$label" "$json" >&2
    exit 1
  fi
}

landscape='[
  {
    "id": 1,
    "name": "LANDSCAPE",
    "width": 1920,
    "height": 1080,
    "x": 0,
    "y": 0,
    "scale": 1,
    "transform": 0,
    "reserved": [10, 30, 20, 40],
    "focused": true,
    "disabled": false
  }
]'
landscape_client='{
  "address": "0x1",
  "monitor": 1,
  "workspace": {"name": "special:music"}
}'

left="$(cliamp_geometry_json \
  "$landscape" "$landscape_client" Left 1200 600)"
center="$(cliamp_geometry_json \
  "$landscape" "$landscape_client" Center 1200 600)"
right="$(cliamp_geometry_json \
  "$landscape" "$landscape_client" Right 1200 600)"
assert_json "$left" \
  '.actual == {x: 10, y: 30, width: 1200, height: 600}' \
  'landscape left alignment'
assert_json "$center" \
  '.actual == {x: 355, y: 30, width: 1200, height: 600}' \
  'landscape center alignment'
assert_json "$right" \
  '.actual == {x: 700, y: 30, width: 1200, height: 600}' \
  'landscape right alignment'

small_right="$(cliamp_geometry_json \
  "$landscape" "$landscape_client" Right 640 360)"
assert_json "$small_right" \
  '.actual == {x: 1260, y: 30, width: 640, height: 360}' \
  'second width uses the usable right edge'

portrait='[
  {
    "id": 4,
    "name": "PORTRAIT",
    "width": 1920,
    "height": 1080,
    "x": -1080,
    "y": 120,
    "scale": 1,
    "transform": 1,
    "reserved": [5, 26, 7, 9],
    "focused": false,
    "disabled": false
  }
]'
portrait_client='{
  "address": "0x2",
  "monitor": 4,
  "workspace": {"name": "special:music"}
}'
portrait_result="$(cliamp_geometry_json \
  "$portrait" "$portrait_client" Center 800 900)"
assert_json "$portrait_result" '
  .monitor.logicalWidth == 1080
  and .monitor.logicalHeight == 1920
  and .usable == {x: -1075, y: 146, width: 1068, height: 1885}
  and .actual == {x: -941, y: 146, width: 800, height: 900}
' 'rotated portrait with non-zero origin and all reserved margins'

scaled='[
  {
    "id": 7,
    "name": "SCALED",
    "width": 3000,
    "height": 1800,
    "x": 100,
    "y": 200,
    "scale": 1.5,
    "transform": 0,
    "reserved": [11, 22, 33, 44],
    "focused": true,
    "disabled": false
  }
]'
scaled_client='{
  "address": "0x3",
  "monitor": 7,
  "workspace": {"name": "special:music"}
}'
oversized="$(cliamp_geometry_json \
  "$scaled" "$scaled_client" Right 9999 9999)"
assert_json "$oversized" '
  .monitor.logicalWidth == 2000
  and .monitor.logicalHeight == 1200
  and .usable == {x: 111, y: 222, width: 1956, height: 1134}
  and .actual == {x: 111, y: 222, width: 1956, height: 1134}
' 'non-1 scale and oversized request clamp'

two_monitors='[
  {
    "id": 1,
    "name": "ACTIVE",
    "width": 1920,
    "height": 1080,
    "x": 0,
    "y": 0,
    "scale": 1,
    "transform": 0,
    "reserved": [0, 26, 0, 0],
    "focused": true,
    "disabled": false
  },
  {
    "id": 2,
    "name": "CLIENT",
    "width": 2560,
    "height": 1440,
    "x": 1920,
    "y": -200,
    "scale": 1,
    "transform": 0,
    "reserved": [20, 40, 30, 50],
    "focused": false,
    "disabled": false
  }
]'
absent="$(cliamp_geometry_json "$two_monitors" null Center 1200 600)"
created_client='{
  "address": "0x4",
  "monitor": 2,
  "workspace": {"name": "special:music"}
}'
created="$(cliamp_geometry_json \
  "$two_monitors" "$created_client" Center 1200 600)"
assert_json "$absent" \
  '.status == "absent" and .monitor.name == "ACTIVE"' \
  'absent client falls back to active monitor'
assert_json "$created" '
  .clientPresent == true
  and .monitor.name == "CLIENT"
  and .actual == {x: 2595, y: -160, width: 1200, height: 600}
' 'created client switches ownership to its monitor'

printf 'ok - geometry cases\n'
