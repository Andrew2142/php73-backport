#!/usr/bin/env bash
# Runs inside ubuntu:18.04 / ubuntu:20.04 / debian:10 for build.sh: builds php7.3 and php-common into /w/out.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive DEBFULLNAME="PHP 7.3 backport" DEBEMAIL="noreply@php73-backport.invalid"
. /etc/os-release
# Debian 10 has moved to archive.debian.org
[ "$ID" != debian ] || printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian buster-updates main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list
apt-get update -qq && apt-get install -y -qq build-essential devscripts equivs fakeroot quilt dpkg-dev >/dev/null

# --- php7.3 ---
cd /tmp && dpkg-source -x /w/src/php7.3_*.dsc php7.3 >/dev/null && cd php7.3
diff <(sed '/^#/d; /^$/d' debian/patches/series) .pc/applied-patches >/dev/null || { echo "not every Sury patch applied"; exit 1; }
mk-build-deps -i -r -t 'apt-get -y -qq --no-install-recommends' debian/control >/dev/null 2>&1
# Sury's php-common.mk switches on the telemetry; Ubuntu's (if any) has none
! grep -qs TELEMETRY /usr/lib/php/php-common.mk || { echo "php-common.mk has telemetry, it would be built in"; exit 1; }
v=$(dpkg-parsechangelog -S Version); v="${v%%+*}+$REV"
dch -b -v "$v" -D "$CODENAME" "Rebuild of Sury php7.3 $(dpkg-parsechangelog -S Version) for $PRETTY_NAME, no source changes."
echo "building php7.3 $v"
DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -uc -us > /w/build-php7.3.log 2>&1 || { tail -30 /w/build-php7.3.log; exit 1; }
! grep -q 'TELEMETRY_HOST' /w/build-php7.3.log || { echo "telemetry was compiled in"; exit 1; }
cp ../*.deb /w/out/

# --- php-common ---
cd /tmp && dpkg-source -x /w/src/php-defaults_*.dsc php-defaults >/dev/null && cd php-defaults
sed -i '/TELEMETRY/d; /^DEB_CFLAGS_MAINT_APPEND += *\\$/d' php-common.mk
! grep -q TELEMETRY php-common.mk || { echo "telemetry still in php-common.mk"; exit 1; }
v=$(dpkg-parsechangelog -S Version); v="${v%%+*}+$REV"
dch -b -v "$v" -D "$CODENAME" "Rebuild of Sury php-defaults $(dpkg-parsechangelog -S Version) for $PRETTY_NAME; telemetry flags removed from php-common.mk."
dpkg-buildpackage -b -uc -us > /w/build-php-defaults.log 2>&1 || { tail -30 /w/build-php-defaults.log; exit 1; }
cp ../php-common_*.deb /w/out/

chown -R "$(stat -c %u:%g /w)" /w
echo "built $(ls /w/out/*.deb | wc -l) packages"
