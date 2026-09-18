#!/bin/bash
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'Usage: bash scripts/capture-store-screen.sh SIMULATOR_UDID iphone|ipad filename-stem' >&2
  exit 1
fi
simulator_id="$1"
family="$2"
shot_name="$3"
[[ "$family" == iphone || "$family" == ipad ]] || { echo 'Choose iphone or ipad.' >&2; exit 1; }
[[ "$shot_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || { echo 'Use a simple filename stem without an extension.' >&2; exit 1; }
command -v xcrun >/dev/null || { echo 'Run this on a Mac with Xcode installed.' >&2; exit 1; }
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$repo_root/release/screenshots/$family"
mkdir -p "$output_dir"
output_path="$output_dir/$shot_name.png"
[[ ! -e "$output_path" ]] || { echo "Already exists: $output_path. Rename or remove it before capturing again." >&2; exit 1; }
xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
trap 'xcrun simctl status_bar "$simulator_id" clear >/dev/null 2>&1 || true' EXIT
xcrun simctl io "$simulator_id" screenshot "$output_path"
sips -g pixelWidth -g pixelHeight "$output_path"
echo "Saved $output_path. Inspect it before uploading."
