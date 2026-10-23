#!/usr/bin/env bash
# Runs inside ubuntu:18.04 / ubuntu:20.04 / debian:10 for build.sh: builds php7.3 and php-common into /w/out.
set -euo pipefail
: "${BUILD_DATE:?set by build.sh}"
export DEBIAN_FRONTEND=noninteractive DEBFULLNAME="PHP 7.3 backport" DEBEMAIL="noreply@php73-backport.invalid"
. /etc/os-release
# Debian 10 has moved to archive.debian.org
[ "$ID" != debian ] || printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian buster-updates main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list
apt-get update -qq && apt-get install -y -qq build-essential devscripts equivs fakeroot quilt dpkg-dev faketime >/dev/null

# --- reproducibility: the same inputs must give byte-identical .debs on any machine ---
# dch stamps the new changelog entry with the current time; replace it with the release's fixed date
pin_date() { sed -i "1,/^ -- /s/^\( -- .*>  \).*/\1$BUILD_DATE/" debian/changelog; }
# The build runs with the clock frozen at that date: phar.phar (php7.3-cli) records the time each file
# was packed. Monotonic clocks still run (sleeps and timeouts work), and file timestamps stay real so
# configure and make see the source tree as it is.
# PHP loads extensions with RTLD_DEEPBIND, which makes them call libc directly and miss libfaketime
# (phar.so takes those times from time()); nodeepbind.so drops that flag while building.
cat > /tmp/nodeepbind.c <<'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
void *dlopen(const char *file, int mode)
{
	static void *(*real)(const char *, int);
	if (!real)
		real = (void *(*)(const char *, int))dlsym(RTLD_NEXT, "dlopen");
	return real(file, mode & ~RTLD_DEEPBIND);
}
EOF
gcc -shared -fPIC -O2 -o /usr/local/lib/nodeepbind.so /tmp/nodeepbind.c -ldl
frozen() {
	TZ=UTC LD_PRELOAD="/usr/local/lib/nodeepbind.so /usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1" \
		DONT_FAKE_MONOTONIC=1 NO_FAKE_STAT=1 \
		FAKETIME="$(date -u -d "$BUILD_DATE" '+%Y-%m-%d %H:%M:%S')" "$@"
}
# Ubuntu 18.04's dtrace (systemtap 3.1) compiles a randomly named temp file with -g, so the random name
# lands in the debug info and changes the build-id of every PHP binary. Give its temp files fixed names.
if [ "$CODENAME" = bionic ]; then
	cat > /usr/local/bin/dtrace <<'EOF'
#!/usr/bin/python
import itertools, sys, tempfile
tempfile._get_candidate_names = lambda: iter("dtrace%d" % i for i in itertools.count())
sys.argv[0] = "/usr/bin/dtrace"
execfile("/usr/bin/dtrace")
EOF
	chmod +x /usr/local/bin/dtrace
fi

# --- php7.3 ---
cd /tmp && dpkg-source -x /w/src/php7.3_*.dsc php7.3 >/dev/null && cd php7.3
diff <(sed '/^#/d; /^$/d' debian/patches/series) .pc/applied-patches >/dev/null || { echo "not every Sury patch applied"; exit 1; }
mk-build-deps -i -r -t 'apt-get -y -qq --no-install-recommends' debian/control >/dev/null 2>&1
# Sury's php-common.mk switches on the telemetry; Ubuntu's (if any) has none
! grep -qs TELEMETRY /usr/lib/php/php-common.mk || { echo "php-common.mk has telemetry, it would be built in"; exit 1; }
v=$(dpkg-parsechangelog -S Version); v="${v%%+*}+$REV"
dch -b -v "$v" -D "$CODENAME" "Rebuild of Sury php7.3 $(dpkg-parsechangelog -S Version) for $PRETTY_NAME, no source changes."
pin_date
echo "building php7.3 $v"
DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" frozen dpkg-buildpackage -b -uc -us > /w/build-php7.3.log 2>&1 || { tail -30 /w/build-php7.3.log; exit 1; }
! grep -q 'TELEMETRY_HOST' /w/build-php7.3.log || { echo "telemetry was compiled in"; exit 1; }
cp ../*.deb /w/out/

# --- php-common ---
cd /tmp && dpkg-source -x /w/src/php-defaults_*.dsc php-defaults >/dev/null && cd php-defaults
sed -i '/TELEMETRY/d; /^DEB_CFLAGS_MAINT_APPEND += *\\$/d' php-common.mk
! grep -q TELEMETRY php-common.mk || { echo "telemetry still in php-common.mk"; exit 1; }
v=$(dpkg-parsechangelog -S Version); v="${v%%+*}+$REV"
dch -b -v "$v" -D "$CODENAME" "Rebuild of Sury php-defaults $(dpkg-parsechangelog -S Version) for $PRETTY_NAME; telemetry flags removed from php-common.mk."
pin_date
frozen dpkg-buildpackage -b -uc -us > /w/build-php-defaults.log 2>&1 || { tail -30 /w/build-php-defaults.log; exit 1; }
cp ../php-common_*.deb /w/out/

chown -R "$(stat -c %u:%g /w)" /w
echo "built $(ls /w/out/*.deb | wc -l) packages"
