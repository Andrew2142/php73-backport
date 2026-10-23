#!/usr/bin/env bash
# Rebuilds Sury's PHP 7.3.33-35 (the php2shell fix, CVE-2026-109618 / CVE-2026-109619) for Ubuntu 18.04
# (bionic), Ubuntu 20.04 (focal) and Debian 10 (buster), which Sury no longer builds for.
#
# The php7.3 source is built exactly as Sury published it. php-common (from php-defaults) is rebuilt
# too, because the new packages need a newer one than these releases have; its php-common.mk loses the
# telemetry build flags so nothing built against it phones home.
#
# The build is reproducible: the base image is pinned by digest, the archives these releases install
# build dependencies from no longer change, and the date below is fixed (see in-container.sh for how it
# is used). reproduce.sh checks that a rebuild gives byte-identical .debs.
#
# Usage: bash build.sh bionic|focal|buster     (needs docker, about 15 minutes each)
# Output: dist/php73-<codename>.tar.gz, the .debs for publish.sh (WORK= and DIST= move the work and output
#         directories; reproduce.sh uses them)

set -euo pipefail
cd "$(dirname "$0")"

CODENAME="${1:-}"
case "$CODENAME" in
	bionic) UB=18.04; IMAGE=ubuntu:18.04@sha256:152dc042452c496007f07ca9127571cb9c29697f42acbfad72324b2bb2e43c98
	        REV=ubuntu18.04.1+backport2 ;;
	focal)  UB=20.04; IMAGE=ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214
	        REV=ubuntu20.04.1+backport2 ;;
	buster) UB=10;    IMAGE=debian:10@sha256:58ce6f1271ae1c8a2006ff7d3e54e9874d839f573d8009c20154ad0f2fb0a225
	        REV=debian10.1+backport2 ;;
	*) echo "usage: bash build.sh bionic|focal|buster"; exit 1 ;;
esac
# the changelog date of this release; it is also the build's frozen clock and SOURCE_DATE_EPOCH
DATE="Fri, 23 Oct 2026 12:00:00 +0000"

SURY=https://packages.sury.org/php/pool/main/p
PHP_V=7.3.33-35+0~20261021.144+debian11~1.gbpecf76f
DEF_V=101+0~20261021.78+debian11~1.gbp53f25f

DIST="${DIST:-dist}"; W="${WORK:-$PWD/work}/$CODENAME"; rm -rf "$W"; mkdir -p "$W/src" "$W/out" "$DIST"

fetch() { # pool path, sha256
	local f="$W/src/$(basename "$1")"
	curl -fsSL "$SURY/${1//+/%2B}" -o "$f"
	echo "$2  $f" | sha256sum -c --quiet || { echo "checksum mismatch: $1"; exit 1; }
}
fetch "php7.3/php7.3_$PHP_V.dsc"                 93994bcd4b966ed4faa4e668dc6475beee00c1ef5494f1011a21fc6b10a86df9
fetch "php7.3/php7.3_$PHP_V.debian.tar.xz"       1aee4a34b2d74ad8c6e2dd94a34bbe94c08d3554197eb31753d39ec0875743cd
fetch "php7.3/php7.3_7.3.33.orig.tar.xz"         166eaccde933381da9516a2b70ad0f447d7cec4b603d07b9a916032b215b90cc
fetch "php7.3/php7.3_7.3.33.orig.tar.xz.asc"     3d15cc09b4c35343ad15fd80b681f126a8efec8efde757e21c04fd54a56ba8d4
fetch "php-defaults/php-defaults_$DEF_V.dsc"     1284e9d5fc91aaa44957a370f80e95761fef94506a9c88491351018bb6521ffc
fetch "php-defaults/php-defaults_$DEF_V.tar.xz"  f7e870d79e64db42de25aa2c5939ca92a87840145d61e219d243a3fc0c2167a2

# /tmp (where the source is unpacked and built) is a tmpfs: it lists directories in creation order, so
# phar.phar packs its files in the same order on every machine (on disk the order depends on the filesystem)
docker run --rm --platform linux/amd64 --tmpfs /tmp:rw,exec,size=8g -e REV="$REV" -e BUILD_DATE="$DATE" -e CODENAME="$CODENAME" -e UB="$UB" -v "$W:/w" -v "$PWD/in-container.sh:/in-container.sh:ro" \
	"$IMAGE" bash /in-container.sh

# Debian 10 servers usually still point at deb.debian.org, which no longer serves buster, so the
# installer's backup tool comes from this repo too (official archive packages, unchanged)
if [ "$CODENAME" = buster ]; then
	DEB=http://archive.debian.org/debian/pool/main/d
	for f in "dpkg/libdpkg-perl_1.19.8_all.deb b445d9aa60b06e5424e17653091684b2928e828bdad2743dd85240f1824c4a8b" \
	         "dpkg-repack/dpkg-repack_1.45_all.deb 2f93fb8ae21296b3d389183ad935f493c7af3e04cc26dbdbfe714bc841a06c9f"; do
		set -- $f; curl -fsSL "$DEB/$1" -o "$W/out/${1#*/}"
		echo "$2  $W/out/${1#*/}" | sha256sum -c --quiet || { echo "checksum mismatch: $1"; exit 1; }
	done
fi

rm -f "$W/out/"*-dbgsym_*.deb   # Debian 10 builds debug symbols too; not shipped
tar czf "$DIST/php73-$CODENAME.tar.gz" -C "$W" --transform "s#^out#php73-$CODENAME#" out
sha256sum "$DIST/php73-$CODENAME.tar.gz"
