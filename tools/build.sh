#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: bash tools/build.sh COMPILER_DIRECTORY INCLUDE_DIRECTORY" >&2
  exit 2
fi
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
compiler_home=$(cd -- "$1" && pwd)
includes=$(cd -- "$2" && pwd)
[[ -x "$compiler_home/amxxpc" ]] || { echo "Missing executable amxxpc" >&2; exit 2; }
for header in amxmodx.inc ApolloRP.inc ApolloRP_Chat.inc tsfun.inc hamsandwich.inc; do
  [[ -f "$includes/$header" ]] || { echo "Missing include: $header" >&2; exit 2; }
done
mkdir -p "$repo/build/plugins"
cd -- "$compiler_home"
for name in Skills Cooking Computers Weapons General Drugs Fighting Law; do
  target="$repo/build/plugins/ARP_$name.amxx"
  rm -f -- "$target"
  ./amxxpc "$repo/addons/amxmodx/scripting/ARP_$name.sma" "-i$repo/addons/amxmodx/scripting/include" "-i$includes" "-o$target"
  [[ -s "$target" ]] || { echo "Missing output for ARP_$name" >&2; exit 1; }
done
echo "Compiled all eight plugins to $repo/build/plugins. Nothing installed or published."
