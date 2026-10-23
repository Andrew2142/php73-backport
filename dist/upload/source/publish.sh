#!/usr/bin/env bash
# Turns dist/php73-{bionic,focal,buster}.tar.gz (from build.sh) into signed apt repos with one-command
# installers.
#
# Usage:  bash publish.sh https://BUCKET.REGION.digitaloceanspaces.com[/PREFIX]
# Output: dist/upload/ - upload everything in it (public-read) so it is served at that URL:
#           install-18.04.sh, install-20.04.sh, install-debian-10.sh (+ .asc signatures),
#           php73-backport.asc (the public key), SHA256SUMS, bionic/, focal/, buster/, source/
#
# Signs with the key in ~/.php73-backport-gnupg. Servers trust only that key: back it up, keep it off
# the web host.

set -euo pipefail
cd "$(dirname "$0")"
ROOT="${1:-}"; ROOT="${ROOT%/}"
[[ "$ROOT" =~ ^https?://[^/]+ ]] || { echo "usage: bash publish.sh https://BUCKET.REGION.digitaloceanspaces.com[/PREFIX]"; exit 1; }
export GNUPGHOME="${GNUPGHOME:-$HOME/.php73-backport-gnupg}"
FPR=9B95FAF14F9E8D38793D1E2717256F38D05BA5EF
# codename  os  version  name  script  package revision
TARGETS="bionic ubuntu 18.04 Ubuntu_18.04 install-18.04.sh ubuntu18.04.1+backport1
focal ubuntu 20.04 Ubuntu_20.04 install-20.04.sh ubuntu20.04.1+backport1
buster debian 10 Debian_10 install-debian-10.sh debian10.1+backport1"

# The servers' apt source is "ROOT/ CODENAME/" (object storage refuses the /./ that a "URL ./" source puts
# in URLs), so package paths in Packages are relative to ROOT: CODENAME/x.deb
rm -rf dist/upload; mkdir -p dist/upload/source
key="$(gpg --export "$FPR" | base64 -w76)"
while read -r c os ver name script rev; do
	name="${name/_/ }"
	[ -f "dist/php73-$c.tar.gz" ] || { echo "missing dist/php73-$c.tar.gz - run: bash build.sh $c"; exit 1; }
	mkdir "dist/upload/$c"
	tar xzf "dist/php73-$c.tar.gz" -C "dist/upload/$c" --strip-components=1 --wildcards '*.deb'
	# php-common is not shipped: Sury's newer one Breaks older PECL packages (php-imagick, php-redis, ...),
	# and every server running PHP 7.3 already has one new enough (php7.3-common needs >= 1:81)
	rm -f "dist/upload/$c/"php-common_*.deb
	( cd dist/upload && apt-ftparchive packages "$c" > "$c/Packages" 2>/dev/null )
	( cd "dist/upload/$c"
	  gzip -9nk Packages
	  apt-ftparchive -o APT::FTPArchive::Release::Origin="php73-backport" \
		-o APT::FTPArchive::Release::Label="PHP 7.3.33-35 (php2shell fix) for $name" \
		-o APT::FTPArchive::Release::Codename="$c/" release . > Release
	  gpg --batch --yes -u "$FPR" --clearsign -o InRelease Release
	  gpg --batch --yes -u "$FPR" -abs -o Release.gpg Release )
	f="dist/upload/$script"
	sed -e "s#@ROOT@#$ROOT#g" -e "s/@OS@/$os/g" -e "s/@VER@/$ver/g" -e "s/@NAME@/$name/g" -e "s/@CODENAME@/$c/g" \
		-e "s/@SCRIPT@/$script/g" -e "s/@REV@/$rev/g" -e "s/@FPR@/$FPR/g" install.sh.in |
		awk -v k="$key" '$0 == "@KEY@" {print k; next} {print}' > "$f"
	bash -n "$f"
	! grep -n '@[A-Z_]*@' "$f" || { echo "unfilled placeholder in $script"; exit 1; }
	gpg --batch --yes -u "$FPR" --armor --detach-sign -o "$f.asc" "$f"
done <<< "$TARGETS"

# source: the exact Sury source the packages were built from, and the build scripts
cp work/focal/src/* build.sh in-container.sh install.sh.in publish.sh dist/upload/source/
gpg --armor --export "$FPR" > dist/upload/php73-backport.asc
( cd dist/upload && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS
  gpg --batch --yes -u "$FPR" --clearsign -o SHA256SUMS.asc SHA256SUMS )
echo "upload everything in $(pwd)/dist/upload so it is served at $ROOT/"
echo "key fingerprint: $FPR"
