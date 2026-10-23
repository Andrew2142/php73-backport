#!/usr/bin/env bash
# Rebuilds one release's .debs from source with build.sh, in a scratch directory, and checks that every
# published .deb in dist/upload/<codename>/ is byte-identical to the rebuild. That is the proof that the
# published packages are Sury's source built exactly as build.sh says, with nothing added.
#
# Usage: bash reproduce.sh bionic|focal|buster     (needs docker, about 15 minutes)
#        REPRO_DIR=/some/dir keeps the rebuild there (the .debs end up in /some/dir/work/<codename>/out)

set -euo pipefail
cd "$(dirname "$0")"
c="${1:-}"
case "$c" in bionic|focal|buster) ;; *) echo "usage: bash reproduce.sh bionic|focal|buster"; exit 1 ;; esac
T="${REPRO_DIR:-$(mktemp -d)}"; mkdir -p "$T"; T="$(cd "$T" && pwd)"

echo "rebuilding $c in $T (about 15 minutes)"
WORK="$T/work" DIST="$T/dist" bash build.sh "$c" > "$T/build.log" 2>&1 || { tail -30 "$T/build.log"; exit 1; }

built="$T/work/$c/out"; pub="dist/upload/$c"; bad=0; n=0
for f in "$pub"/*.deb; do
	b=$(basename "$f"); n=$((n + 1))
	if [ ! -f "$built/$b" ]; then echo "  MISSING  $b"; bad=1
	elif cmp -s "$f" "$built/$b"; then echo "  same     $b"
	else echo "  DIFFERS  $b"; bad=1; fi
done
[ $bad -eq 0 ] || { echo "the rebuild differs from what is published - see: diffoscope $pub/<file> $built/<file>"; exit 1; }
echo "all $n published .debs for $c are byte-identical to the rebuild"
