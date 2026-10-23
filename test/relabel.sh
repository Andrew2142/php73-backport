#!/usr/bin/env bash
# Test fixture: turns the built -35 .debs in /debs into a fake unfixed "-8" PHP 7.3 in /old (the PPA's
# bionic/focal pool is gone, so there is no real old build to install). Version and changelog only.
set -euo pipefail
mkdir -p /old /tmp/rl
for d in /debs/*.deb; do
	r=/tmp/rl/x; rm -rf $r; dpkg-deb -R "$d" $r
	sed -i -E 's/7\.3\.33-35\+ubuntu[0-9.]+\.1\+backport[0-9]*/7.3.33-8+ubuntu1/g; s/2:101\+ubuntu[0-9.]+\.1\+backport[0-9]*/2:100+ubuntu1/g; s/^(Version: )101\+ubuntu[0-9.]+\.1\+backport[0-9]*/\1100+ubuntu1/' $r/DEBIAN/control
	for c in $r/usr/share/doc/*/changelog.Debian.gz; do
		[ -f "$c" ] && zcat "$c" | grep -v 'CVE-2026-10961[89]' | gzip -9n > "$c.n" && mv "$c.n" "$c"
	done
	( cd $r && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | xargs -0 md5sum > DEBIAN/md5sums )
	dpkg-deb -b $r "/old/old-$(basename "$d")" >/dev/null
done
