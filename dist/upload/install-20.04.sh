#!/usr/bin/env bash
# php2shell fix (CVE-2026-109618 / CVE-2026-109619) for PHP 7.3 on Ubuntu 20.04 (focal), amd64.
#
#   curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh | sudo bash                 asks before each step
#   curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh | sudo bash -s -- --yes     no questions (lockdown included)
#
# Other systems:  Ubuntu 18.04: https://php73-backport.fra1.digitaloceanspaces.com/install-18.04.sh
#                 Ubuntu 20.04: https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh
#                 Debian 10:    https://php73-backport.fra1.digitaloceanspaces.com/install-debian-10.sh
#
# What it does, step by step: see HELP below, or run it with --help.

HELP=$(cat <<'TXT'
WHY THIS EXISTS
  The fix for php2shell is in PHP 7.3.33-35 from Ondrej Sury, but Sury only publishes it for
  Ubuntu 22.04/24.04 and Debian 11-13. Ubuntu 18.04 and 20.04 (PHP 7.3 from ppa:ondrej/php) and
  Debian 10 (PHP 7.3 is its own default PHP) have no fixed package. This repo is Sury's 7.3.33-35
  source rebuilt unchanged for Ubuntu 20.04 (versions end in +ubuntu20.04.1+backport1), against the
  distribution's own build tools, so the telemetry build flags in Sury's newer php-common are not
  compiled in: nothing here contacts any outside host. Your php-common is not changed, so PHP
  extensions from other packages (php-imagick, php-redis, php-memcached, ...) keep working.
  Debian 10 ELTS (Freexian, paid) customers: check whether your ELTS PHP already has the fix first.

WHAT YOU ARE TRUSTING
  The packages and this script are signed with this repo's key (fingerprint 9B95FAF14F9E8D38793D1E2717256F38D05BA5EF).
  Adding any apt repo lets its key holder ship packages to your server. To limit that, this
  script pins apt (/etc/apt/preferences.d/php73-backport.pref) so this repo can ONLY supply
  php7.3-*, libapache2-mod-php7.3 and libphp7.3-embed (plus, on Debian 10, Debian's own unchanged
  dpkg-repack and libdpkg-perl for the backup) - never any other package, not even php-common.
  That limits which packages it can supply, not what they can do: like any package, their install
  scripts run as root.
  Remove the repo at any time with --remove-repo (PHP stays fixed, you just get no further updates).
  Build scripts and the exact Sury source used: https://php73-backport.fra1.digitaloceanspaces.com/source/

  To check the script before running it:
    curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh && curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh.asc
    curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/php73-backport.asc | gpg --import
    gpg --verify install-20.04.sh.asc install-20.04.sh        (must say "Good signature", fingerprint 9B95FAF14F9E8D38793D1E2717256F38D05BA5EF)
    less install-20.04.sh && sudo bash install-20.04.sh

WHAT IT DOES, IN ORDER
  0. Checks, before changing anything: root, Ubuntu 20.04, amd64, PHP 7.3 installed from apt, no
     half-installed or held PHP packages, enough disk space, no other apt/dpkg running (waits up to
     5 minutes for unattended-upgrades). Notes control panels (cPanel, Plesk, DirectAdmin, aaPanel,
     LiteSpeed) whose own PHP builds this does not touch. Shows what it found (mod_php, PHP-FPM,
     Apache, nginx) and the plan, and asks before starting.
  1. Repo: writes the signing key to /usr/share/keyrings/php73-backport.gpg, the apt source to
     /etc/apt/sources.list.d/php73-backport.list and the pin above. Checks the repo has a fixed
     build of every PHP 7.3 package installed here; if not, removes the repo again and stops.
  2. Backup: saves the PHP 7.3 packages installed now (as .deb files, made with dpkg-repack) to
     /var/backups/php73-pre-backport, so --restore can put them back exactly. (--no-backup skips it.)
  3. Update: upgrades only the PHP 7.3 packages already installed. No PHP package is added or
     removed (apt may add newer libraries they need), your php.ini and pool files are kept. If the
     upgrade switched on Apache modules (it can enable mod_php and mpm_prefork on a PHP-FPM server)
     they are switched back. Then it checks the package changelog lists both CVEs, and that every
     PHP extension that loaded before (ionCube, imagick, redis, ...) still loads, for the CLI,
     PHP-FPM and Apache. The packages restart PHP-FPM (and Apache, with mod_php) themselves while
     upgrading, so if an extension no longer loads the site is already running without it: the
     script stops and tells you to put the old PHP back with --restore.
  4. Lockdown (asked separately; skip with --no-lockdown). Extra protection on top of the fix:
       - PHP: session.upload_progress.enabled = Off, in /etc/php/7.3/<sapi>/conf.d/zz-php2shell.ini
       - Apache: /etc/apache2/conf-available/zz-php2shell.conf (enabled with a2enconf): request bodies
         capped (LimitRequestBody), and multipart uploads without a Content-Length header (chunked
         uploads) refused with 403. The config is tested (apache2ctl -t) and removed if rejected.
     The Apache cap is 32MB, or your PHP post_max_size if that is bigger, so PHP form uploads your
     site accepts today keep working. It applies to every site on this Apache: a non-PHP app, or a
     PHP PUT/raw upload, bigger than that gets HTTP 413 - raise it in the file above if needed. No
     cap if post_max_size is 0 (unlimited) or 2GB or more (Apache's maximum).
     nginx gets nothing: its own client_max_body_size (1MB unless your config raises it) already
     applies. An nginx size cap written by an earlier version of this script is removed, because
     it raised that 1MB default.
  5. Restart: PHP-FPM 7.3 and Apache are restarted, nginx reloaded (whichever are running;
     requests in progress are cut), then it checks nothing is still running the old PHP.
     Long-running PHP CLI processes (queue workers, daemons) are not restarted - they are listed
     so you can restart them yourself.
  6. Check: a chunked upload to 127.0.0.1 is refused (Apache lockdown), and prints the result.
  Everything is logged to /var/log/php2shell-backport-<date>.log.

NOT COVERED
  - Other PHP versions (5.6, 7.0-7.2, 7.4, 8.x) and other systems. Only PHP 7.3.
  - PHP from control panels (cPanel ea-php73, Plesk plesk-php73, DirectAdmin, aaPanel,
    LiteSpeed lsphp73) or compiled by hand: get the fix from that vendor.
  - arm64 and other non-amd64 servers: no build.
  - CVE-2026-9672 (libgd GIF decoder overflow). Sury's -35 patches the copy of libgd bundled in
    the PHP source, but Debian/Ubuntu PHP packages (Sury's included) use the system libgd3, so that
    patch is not used. Ubuntu has not fixed libgd3 for any release yet; Debian 10's libgd3 is only
    fixed in paid ELTS. PHP code that decodes untrusted GIFs with gd (imagecreatefromgif,
    imagecreatefromstring) stays exposed. Avoid decoding untrusted GIFs with gd.

OPTIONS (after "bash -s --" when piped)
  --yes          no questions
  --no-lockdown  only update PHP, skip step 4
  --no-backup    skip step 2 (no --restore possible afterwards)
  --rollback     remove the lockdown only (PHP stays fixed)
  --remove-repo  remove this repo, its key and pin (PHP stays fixed, no further updates)
  --restore      put the old PHP back from /var/backups/php73-pre-backport, remove the lockdown and
                 this repo. The server is then UNFIXED again.
  --help         show this text
TXT
)

say()  { echo "==> $*"; }
warn() { echo "==> CHECK: $*"; WARN=1; }
die()  { echo; echo "NOT DONE: $*"; exit 1; }

# Everything is inside main so bash has read the whole script before a command can eat stdin.
main() {
set -uo pipefail
export LC_ALL=C DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1
export PATH="/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
ROOT=https://php73-backport.fra1.digitaloceanspaces.com
ROOT_HOST="${ROOT#*://}"; ROOT_HOST="${ROOT_HOST%%/*}"; ROOT_HOST="${ROOT_HOST%%:*}"   # apt pins match the host without port
LIST=/etc/apt/sources.list.d/php73-backport.list
KEYRING=/usr/share/keyrings/php73-backport.gpg
PREF=/etc/apt/preferences.d/php73-backport.pref
BACKUP=/var/backups/php73-pre-backport
INI_NAME=zz-php2shell.ini
ACONF=/etc/apache2/conf-available/zz-php2shell.conf
NCONF=/etc/nginx/conf.d/zz-php2shell.conf
CHANGELOG=/usr/share/doc/php7.3-common/changelog.Debian.gz
SAPIS="cli fpm apache2"
YES=0; LOCK=1; LOCKED=0; BACKUP_ON=1; MODE=install; WARN=0
for a in "$@"; do case "$a" in
	--yes) YES=1 ;; --no-lockdown) LOCK=0 ;; --no-backup) BACKUP_ON=0 ;;
	--rollback) MODE=rollback ;; --restore) MODE=restore ;; --remove-repo) MODE=remove-repo ;;
	--help|-h) echo "$HELP"; exit 0 ;;
	*) die "unknown option: $a (try --help)" ;;
esac; done

ask() {
	[ $YES -eq 1 ] && return 0
	local a; read -r -p "$1 [y/N] " a < /dev/tty || return 1; [[ "$a" =~ ^[Yy] ]]
}
fixed() { local c; c="$(zcat "$CHANGELOG" 2>/dev/null)"; grep -q CVE-2026-109618 <<< "$c" && grep -q CVE-2026-109619 <<< "$c"; }
# services, with or without systemd (containers, old VPS)
SYSTEMD=0; [ -d /run/systemd/system ] && SYSTEMD=1
active() {
	if [ $SYSTEMD -eq 1 ]; then systemctl is-active --quiet "$1" 2>/dev/null; return; fi
	case "$1" in
		php7.3-fpm) pgrep -f '^php-fpm: master process .*7\.3' ;;
		*) pgrep -x "$1" ;;
	esac >/dev/null 2>&1
}
svc() { if [ $SYSTEMD -eq 1 ]; then systemctl "$1" "$2"; else service "$2" "$1"; fi; }
# PHP 7.3 packages built from the php7.3 source (not separately versioned extras like php7.3-imagick)
php_pkgs() { dpkg-query -W -f='${binary:Package} ${source:Package} ${db:Status-Abbrev}\n' 'php7.3*' libapache2-mod-php7.3 libphp7.3-embed 2>/dev/null | awk '$2 == "php7.3" && $3 ~ /^ii/ {sub(/:.*/, "", $1); print $1}'; }
# extensions each SAPI's config loads, as "sapi:module" lines (checked with the CLI binary)
php_mods() {
	local s; for s in $SAPIS; do
		[ -f "/etc/php/7.3/$s/php.ini" ] || continue
		PHP_INI_SCAN_DIR="/etc/php/7.3/$s/conf.d" php7.3 -c "/etc/php/7.3/$s/php.ini" -m 2>/dev/null | grep -v '^\[' | grep . | sed "s/^/$s:/"
	done | sort -u
}
# PHP startup errors of each SAPI's config (an extension missing or failing to load), as "sapi: message" lines
load_errors() {
	local s; for s in $SAPIS; do
		[ -f "/etc/php/7.3/$s/php.ini" ] || continue
		PHP_INI_SCAN_DIR="/etc/php/7.3/$s/conf.d" php7.3 -c "/etc/php/7.3/$s/php.ini" -m 2>&1 >/dev/null | grep . | sed "s/^/$s: /"
	done | sort -u
}
# biggest post_max_size of the web SAPIs, in MB (0 = unlimited)
post_max_mb() {
	local s v n max=0
	for s in fpm apache2 cgi; do
		[ -f "/etc/php/7.3/$s/php.ini" ] || continue
		v="$(PHP_INI_SCAN_DIR="/etc/php/7.3/$s/conf.d" php7.3 -c "/etc/php/7.3/$s/php.ini" -r 'echo ini_get("post_max_size");' 2>/dev/null)"
		case "$v" in
			0|"") [ "$v" = 0 ] && { echo 0; return; }; continue ;;
			*[Gg]) n=$(( ${v%[Gg]} * 1024 )) ;; *[Mm]) n=${v%[Mm]} ;; *[Kk]) n=$(( (${v%[Kk]} + 1023) / 1024 )) ;;
			*) n=$(( (v + 1048575) / 1048576 )) ;;
		esac
		[ "$n" -gt "$max" ] && max=$n
	done
	echo "$max"
}
apache_mods() { ls /etc/apache2/mods-enabled/ 2>/dev/null | sed -n 's/\.load$//p' | sort; }
restore_apache_mods() {
	[ -d /etc/apache2/mods-enabled ] && command -v a2enmod >/dev/null || return 0
	local m
	# mpm_* last: Apache refuses to disable an MPM while a module that needs it (mod_php) is still on
	for m in $(comm -13 <(echo "$1") <(apache_mods) | awk '/^mpm_/ {l = l " " $0; next} {print} END {print l}'); do
		say "the upgrade enabled Apache module $m, disabling it again"; a2dismod -q "$m" >/dev/null 2>&1
	done
	for m in $(comm -23 <(echo "$1") <(apache_mods)); do
		say "the upgrade disabled Apache module $m, enabling it again"; a2enmod -q "$m" >/dev/null 2>&1
	done
	[ "$(apache_mods)" = "$1" ] || die "Apache modules differ from before the upgrade - compare: ls /etc/apache2/mods-enabled (before: $(echo $1))"
}
# installed PHP 7.3 packages that have no .deb in the backup
not_in_backup() {
	local p; for p in $(php_pkgs); do
		ls "$BACKUP/${p}_"*.deb >/dev/null 2>&1 || printf ' %s' "$p"
	done
}
remove_lockdown() {
	a2disconf -q zz-php2shell >/dev/null 2>&1
	rm -f "$ACONF" "$NCONF" /etc/php/7.3/*/conf.d/$INI_NAME
}
remove_repo() { rm -f "$LIST" "$KEYRING" "$PREF"; apt-get -qq update >/dev/null 2>&1; }
# wait for unattended-upgrades or another apt/dpkg run
apt_wait() {
	local i; for i in $(seq 60); do
		# not "unattended-upgr" by name: unattended-upgrade-shutdown --wait-for-signal is always running
		{ pgrep -x 'apt|apt-get|aptitude|dpkg' || pgrep -f '/usr/bin/unattended-upgrade( |$)'; } >/dev/null || return 0
		[ "$i" -eq 1 ] && say "waiting for another apt/dpkg run to finish (unattended-upgrades?)"
		sleep 5
	done
	die "apt/dpkg is still busy after 5 minutes - try again later"
}
# PIDs still running the PHP 7.3 that was replaced on disk
old_php_pids() {
	local p; for p in /proc/[0-9]*; do
		{ [[ "$(readlink "$p/exe" 2>/dev/null)" == *php*7.3*"(deleted)"* ]] || grep -qsE 'libphp7\.3\.so \(deleted\)' "$p/maps"; } && echo "${p#/proc/}"
	done
}
restart_web() {
	if [ $APACHE -eq 1 ]; then
		apache2ctl -t >/dev/null 2>&1 || die "Apache config test fails, nothing restarted: $(apache2ctl -t 2>&1 | tail -1)"
	fi
	if [ $NGINX -eq 1 ]; then
		nginx -t >/dev/null 2>&1 || die "nginx config test fails, nothing restarted: $(nginx -t 2>&1 | tail -1)"
	fi
	if [ $FPM -eq 1 ]; then
		php-fpm7.3 -t >/dev/null 2>&1 || die "PHP-FPM config test fails, nothing restarted: $(php-fpm7.3 -t 2>&1 | tail -1)"
		say "restarting PHP-FPM 7.3"; svc restart php7.3-fpm >/dev/null 2>&1 || die "PHP-FPM did not restart - check: service php7.3-fpm status"
	fi
	if [ $APACHE -eq 1 ]; then
		say "restarting Apache"; svc restart apache2 >/dev/null 2>&1 || die "Apache did not restart - check: service apache2 status"
	fi
	if [ $NGINX -eq 1 ]; then
		say "reloading nginx"; svc reload nginx >/dev/null 2>&1 || die "nginx did not reload - check: service nginx status"
	fi
	sleep 2
	[ $APACHE -eq 0 ] || active apache2 || die "Apache is NOT running - check: service apache2 status"
	[ $FPM -eq 0 ] || active php7.3-fpm || die "PHP-FPM is NOT running - check: service php7.3-fpm status"
	[ $NGINX -eq 0 ] || active nginx || die "nginx is NOT running - check: service nginx status"
}

[ "$(id -u)" -eq 0 ] || die "run as root: curl -fsSL $ROOT/install-20.04.sh | sudo bash"
. /etc/os-release
case "${ID:-} ${VERSION_ID:-}" in
	"ubuntu 20.04") ;;
	"ubuntu 18.04") die "this script is for Ubuntu 20.04, this server is $PRETTY_NAME - use: curl -fsSL $ROOT/install-18.04.sh | sudo bash" ;;
	"ubuntu 20.04") die "this script is for Ubuntu 20.04, this server is $PRETTY_NAME - use: curl -fsSL $ROOT/install-20.04.sh | sudo bash" ;;
	"debian 10")    die "this script is for Ubuntu 20.04, this server is $PRETTY_NAME - use: curl -fsSL $ROOT/install-debian-10.sh | sudo bash" ;;
	"ubuntu 22.04"|"ubuntu 24.04") die "$PRETTY_NAME does not need this: the fix is in ppa:ondrej/php - run: apt update && apt install --only-upgrade 'php7.3*'" ;;
	"debian 11"|"debian 12"|"debian 13") die "$PRETTY_NAME does not need this: the fix is in packages.sury.org/php - run: apt update && apt install --only-upgrade 'php7.3*'" ;;
	*) die "this is for Ubuntu 20.04 only, this server is ${PRETTY_NAME:-unknown}" ;;
esac
arch="$(dpkg --print-architecture)"
[ "$arch" = amd64 ] || die "this server is $arch - only amd64 builds exist"
[ $YES -eq 1 ] || { [ -r /dev/tty ] && : < /dev/tty; } 2>/dev/null || die "no terminal to ask questions on - add: -s -- --yes"
exec > >(tee -a "/var/log/php2shell-backport-$(date +%Y%m%d-%H%M%S).log") 2>&1

MODPHP=0; [ -e /etc/apache2/mods-enabled/php7.3.load ] && MODPHP=1
FPM=0; active php7.3-fpm && FPM=1
APACHE=0; command -v apache2ctl >/dev/null && active apache2 && APACHE=1
NGINX=0; command -v nginx >/dev/null && active nginx && NGINX=1

if [ $MODE = rollback ]; then
	remove_lockdown; restart_web
	echo; echo "DONE: lockdown removed (PHP stays as it is: $(dpkg-query -W -f='${Version}' php7.3-common 2>/dev/null))."; exit 0
fi
if [ $MODE = remove-repo ]; then
	remove_repo
	echo; echo "DONE: repo, key and pin removed. PHP stays at $(dpkg-query -W -f='${Version}' php7.3-common 2>/dev/null)."; exit 0
fi
if [ $MODE = restore ]; then
	[ -n "$(ls "$BACKUP"/*.deb 2>/dev/null)" ] || die "no backup in $BACKUP"
	# a PHP 7.3 package installed after the backup has no old version to go back to, and dpkg could not
	# configure it next to the old php7.3-common
	missing="$(not_in_backup)"
	[ -z "$missing" ] || die "the backup has no old version of:$missing (installed after the backup was made) - remove them first (apt-get remove$missing), then run --restore again"
	echo "This puts back the PHP saved in $BACKUP. PHP will be UNFIXED (vulnerable to php2shell) again."
	ask "Restore the old PHP?" || { echo "Nothing changed."; exit 2; }
	apt_wait
	mods_before="$(apache_mods)"
	# --force-confold: a repacked conffile would otherwise prompt and, without a terminal, leave PHP half-installed
	dpkg -i --force-confold --force-downgrade "$BACKUP"/*.deb >>/var/log/php2shell-backport-dpkg.log 2>&1 || die "dpkg failed, see /var/log/php2shell-backport-dpkg.log"
	restore_apache_mods "$mods_before"
	remove_repo; remove_lockdown; restart_web
	echo; echo "DONE: PHP restored to $(dpkg-query -W -f='${Version}' php7.3-common). This server is NOT protected against php2shell."; exit 0
fi

# --- 0. checks, nothing changed yet ---
panel=""
[ -d /usr/local/cpanel ]      && panel="cPanel (ea-php73)"
[ -d /usr/local/psa ]         && panel="Plesk (plesk-php73)"
[ -d /usr/local/directadmin ] && panel="DirectAdmin (CustomBuild PHP)"
[ -d /www/server/panel ]      && panel="aaPanel (its own PHP builds)"
[ -d /usr/local/lsws ]        && panel="LiteSpeed/CyberPanel (lsphp73)"
if ! dpkg-query -W -f='${Status}' php7.3-common 2>/dev/null | grep -q 'ok installed'; then
	[ -z "$panel" ] || die "PHP 7.3 is not installed from apt here. This server runs $panel, which ships its own PHP - get the fix from that vendor."
	die "PHP 7.3 (php7.3-common) is not installed from apt here - this only fixes apt-installed PHP 7.3"
fi
cur="$(dpkg-query -W -f='${Version}' php7.3-common)"
[ -z "$(dpkg --audit 2>/dev/null)" ] || die "dpkg has half-installed packages - fix them first: dpkg --configure -a && apt-get -f install"
held="$(apt-mark showhold 2>/dev/null | grep -E '^(php7\.3|libapache2-mod-php7\.3|libphp7\.3|php-common)' | paste -sd' ' -)"
[ -z "$held" ] || die "these packages are on hold: $held - release them first: apt-mark unhold $held"
for d in /var /usr; do
	free=$(df -Pk "$d" | awk 'NR == 2 {print int($4 / 1024)}')
	[ "$free" -ge 300 ] || die "only ${free}MB free on $d, need 300MB"
done

echo
say "server $(hostname -f 2>/dev/null || hostname): $PRETTY_NAME, PHP 7.3 $cur"
say "PHP 7.3 runs via:$([ $MODPHP -eq 1 ] && echo " mod_php (inside Apache)")$([ $FPM -eq 1 ] && echo " PHP-FPM")$([ $MODPHP -eq 0 ] && [ $FPM -eq 0 ] && echo " CLI only")"
say "web servers running:$([ $APACHE -eq 1 ] && echo " Apache")$([ $NGINX -eq 1 ] && echo " nginx")$([ $APACHE -eq 0 ] && [ $NGINX -eq 0 ] && echo " none found")"
[ $SYSTEMD -eq 1 ] || say "no systemd here, using the service command"
[ -z "$panel" ] || say "note: $panel found - only the apt PHP 7.3 is updated, the panel's own PHP builds are not touched"
other="$(ls /etc/php 2>/dev/null | grep -vx 7.3 | paste -sd' ' -)"
[ -z "$other" ] || say "note: PHP $other also installed - only PHP 7.3 is updated"
echo
echo "  Plan: 1. add the PHP 7.3 backport repo for $PRETTY_NAME (pinned to PHP 7.3 packages only)"
echo "        2. $([ $BACKUP_ON -eq 1 ] && echo "back up the current PHP to $BACKUP" || echo "no backup (--no-backup)")"
echo "        3. upgrade the installed PHP 7.3 packages to 7.3.33-35 (the php2shell fix)"
echo "        4. $([ $LOCK -eq 1 ] && echo "lockdown: upload progress off, request size cap, chunked uploads refused (asked separately)" || echo "no lockdown (--no-lockdown)")"
echo "        5. restart PHP-FPM / Apache / nginx (whichever run here; requests in progress are cut)"
echo "  Details: curl -fsSL $ROOT/install-20.04.sh | bash -s -- --help"
echo
ask "Start?" || { echo "Nothing changed."; exit 2; }
apt_wait

# --- 1. repo ---
say "adding the PHP 7.3 backport repo ($ROOT focal/)"
base64 -d > "$KEYRING" <<'KEY'
mDMEatst7RYJKwYBBAHaRw8BAQdADH5+bjwt+QrFmokigxBbyWpQcJCqZjH5vfRYH/5UKVO0PFBI
UCA3LjMgYmFja3BvcnRzIGZvciBVYnVudHUgMTguMDQgYW5kIDIwLjA0IChwaHAyc2hlbGwgZml4
KYh4BDAWCgAgFiEEm5X68U+ejTh5PR4nFyVvONBbpe8FAmrbPrYCHSAACgkQFyVvONBbpe/0/wD/
SWKutqbiKzvw4v3mD66bENZE/r7ziBSF5x4t0pW+aCQA/Ry0f+zSGb6tNAuYoH21/oErld0Hq8Xf
QkW+wvUghtQBiJMEExYKADsWIQSblfrxT56NOHk9HicXJW840Ful7wUCatst7QIbAwULCQgHAgIi
AgYVCgkICwIEFgIDAQIeBwIXgAAKCRAXJW840Ful7zmrAPwNU8czge1UlXz7jqGDxNtIU8Lo0fJw
UYcw5V1JBNxhiQD/Y2bnTfE0WbXQ+cXRku6MCmgInm9cJ0uw/DtM2gKs2Au0R1BIUCA3LjMgYmFj
a3BvcnRzIGZvciBVYnVudHUgMTguMDQsIDIwLjA0IGFuZCBEZWJpYW4gMTAgKHBocDJzaGVsbCBm
aXgpiJMEExYKADsWIQSblfrxT56NOHk9HicXJW840Ful7wUCats+tgIbAwULCQgHAgIiAgYVCgkI
CwIEFgIDAQIeBwIXgAAKCRAXJW840Ful77rhAQD3Pj76GQEuvlGHjlFD7nic9iyf3jW6VutlSEX7
TyCYKQD+IwyypJk2/VqZIBnTUb1dVGSAUOYjkSr08tozX0iwywQ=
KEY
cat > "$PREF" <<PIN
# php73-backport: this repo may only supply PHP 7.3 packages (removed by --remove-repo / --restore)
Package: php7.3* libapache2-mod-php7.3 libphp7.3-embed dpkg-repack libdpkg-perl
Pin: origin "$ROOT_HOST"
Pin-Priority: 500

Package: *
Pin: origin "$ROOT_HOST"
Pin-Priority: -1
PIN
echo "deb [signed-by=$KEYRING] $ROOT/ focal/" > "$LIST"
apt-get -qq update -o Dir::Etc::sourcelist="$LIST" -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0 >/dev/null 2>&1 \
	|| { remove_repo; die "could not read the repo at $ROOT/focal/ (repo removed again, nothing changed)"; }
cand="$(apt-cache policy php7.3-common | awk '/Candidate:/ {print $2}')"
case "$cand" in *+backport*) say "fixed PHP available: $cand" ;; *) remove_repo; die "the repo does not offer the fixed PHP (candidate: $cand) - repo removed again, nothing changed" ;; esac
missing=""
for p in $(php_pkgs); do
	[[ "$(apt-cache policy "$p" | awk '/Candidate:/ {print $2}')" == *+backport* ]] || missing="$missing $p"
done
[ -z "$missing" ] || { remove_repo; die "no fixed build in the repo for:$missing - repo removed again, nothing changed"; }

# --- 2. backup ---
if [[ "$cur" == *+backport* ]]; then
	say "already on the backport ($cur), no backup needed"
elif [ $BACKUP_ON -eq 0 ]; then
	say "backup skipped (--no-backup)"
else
	fresh=0
	if [ -n "$(ls "$BACKUP"/*.deb 2>/dev/null)" ]; then
		# an earlier run's backup: add PHP 7.3 packages installed since, so --restore covers them
		need="$(not_in_backup)"
		if [ -z "$need" ]; then say "backup already in $BACKUP"
		else say "adding to the backup in $BACKUP (installed since it was made):$need"; fi
	else
		fresh=1; need="php-common $(php_pkgs)"
		say "saving the current PHP packages ($cur) to $BACKUP"
	fi
	if [ -n "$need" ]; then
		if ! command -v dpkg-repack >/dev/null; then
			err="$(apt-get -y -q install dpkg-repack 2>&1 </dev/null)" || {
				remove_repo
				die "could not install dpkg-repack, the backup tool (repo removed again, nothing changed):
$(grep -E '^ |^E:' <<< "$err" | head -5)
  Fix this server's apt sources, or run again with --no-backup (then --restore is not possible)"; }
		fi
		mkdir -p "$BACKUP"
		( cd "$BACKUP" && dpkg-repack $need >/dev/null 2>&1 ) \
			|| { [ $fresh -eq 0 ] || rm -rf "$BACKUP"; remove_repo; die "dpkg-repack failed (repo removed again, nothing changed) - or run again with --no-backup"; }
		say "saved $(ls "$BACKUP"/*.deb | wc -l) packages"
	fi
fi

# --- 3. update ---
if fixed; then
	say "PHP 7.3 already has the fix ($cur)"
else
	pkgs="$(php_pkgs | paste -sd' ' -)"
	mods_before="$(php_mods)"; errs_before="$(load_errors)"; amods_before="$(apache_mods)"
	restore_hint="$([ -n "$(ls "$BACKUP"/*.deb 2>/dev/null)" ] && echo "put the old PHP back by running this script again with --restore" || echo "there is no backup (--no-backup)")"
	say "upgrading to $cand: $pkgs"
	apt_wait
	if ! apt-get -y -q -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --no-remove \
		install --only-upgrade $pkgs </dev/null >>/var/log/php2shell-backport-apt.log 2>&1; then
		say "apt failed, undoing any Apache module changes it made"
		restore_apache_mods "$amods_before"
		die "apt failed, see /var/log/php2shell-backport-apt.log - $restore_hint"
	fi
	restore_apache_mods "$amods_before"
	fixed || die "PHP upgraded but its changelog does not list the fix - check $CHANGELOG"
	lost="$(comm -23 <(echo "$mods_before") <(php_mods))"
	new_errs="$(comm -13 <(echo "$errs_before") <(load_errors))"
	[ -z "$lost$new_errs" ] || die "PHP extensions that loaded before do not load with the new PHP:
$({ echo "$lost" | sed 's/^/     not loaded: /'; echo "$new_errs" | sed 's/^/     /'; } | grep -vE '^ +(not loaded: )?$')
  The package upgrade has already restarted PHP-FPM / Apache, so the site is running without them now:
  $restore_hint"
	say "PHP 7.3 is now $(dpkg-query -W -f='${Version}' php7.3-common), all extensions still load"
fi
# also on a re-run, when step 3 had nothing to do
errs="$(load_errors)"
[ -z "$errs" ] || warn "PHP reports startup errors (an extension missing or failing to load):
$(echo "$errs" | sed 's/^/     /')"

# --- 4. lockdown ---
# earlier versions wrote an nginx client_max_body_size, which raised nginx's 1MB default instead of capping
if [ -f "$NCONF" ]; then
	rm -f "$NCONF"; say "removed $NCONF from an earlier run (it raised nginx's 1MB upload limit)"
fi
if [ $LOCK -eq 1 ] && ask "Apply the lockdown (upload progress off, request size cap, chunked uploads refused)?"; then
	remove_lockdown
	pm=$(post_max_mb); cap=32; [ "$pm" -gt 32 ] && cap=$pm
	if [ "$pm" -eq 0 ]; then cap=0; say "post_max_size is unlimited, so no request size cap"
	elif [ $cap -ge 2048 ]; then cap=0; say "post_max_size is ${pm}MB, above Apache's 2GB maximum, so no request size cap"
	elif [ $cap -gt 32 ]; then say "request size cap ${cap}MB (your post_max_size) instead of 32MB"; fi
	for s in apache2 fpm cgi; do
		[ -d "/etc/php/7.3/$s/conf.d" ] || continue
		printf '; php2shell lockdown (install-20.04.sh --rollback removes it)\nsession.upload_progress.enabled = Off\n' > "/etc/php/7.3/$s/conf.d/$INI_NAME"
	done
	if [ -d /etc/apache2/conf-available ] && command -v apache2ctl >/dev/null; then
		{ echo '# php2shell lockdown (install-20.04.sh --rollback removes it)'
		  echo '<IfModule php7_module>'
		  echo '    php_admin_flag session.upload_progress.enabled off'
		  echo '</IfModule>'
		  [ $cap -eq 0 ] || echo "LimitRequestBody $(( cap * 1048576 ))"
		  echo "<If \"%{REQUEST_METHOD} == 'POST' && %{HTTP:Content-Type} =~ m#multipart/#i && -z %{HTTP:Content-Length}\">"
		  echo '    Require all denied'
		  echo '</If>'; } > "$ACONF"
		a2enconf -q zz-php2shell >/dev/null
		apache2ctl -t >/dev/null 2>&1 || { a2disconf -q zz-php2shell >/dev/null 2>&1; rm -f "$ACONF"; warn "Apache rejected the lockdown config, left it out: $(apache2ctl -t 2>&1 | tail -1)"; }
	fi
	LOCKED=1; say "lockdown written"
else
	say "lockdown skipped"
fi

# --- 5. restart ---
restart_web
web_old=""; cli_old=""
for p in $(old_php_pids); do
	c="$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-120)"
	case "$c" in php-fpm:*|*apache2*|*httpd*) web_old="$web_old $p" ;; *) cli_old="$cli_old"$'\n'"     $p  $c" ;; esac
done
[ -z "$web_old" ] || die "the web server is still running the old PHP (pids$web_old) - restart PHP-FPM / Apache by hand"
[ -z "$cli_old" ] || warn "these PHP processes still run the old PHP 7.3 - restart them (supervisor, systemd, cron daemons):$cli_old"

# --- 6. check ---
if [ -f "$ACONF" ] && [ $APACHE -eq 1 ]; then
	code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H 'Transfer-Encoding: chunked' -F f=@/etc/hostname http://127.0.0.1/php2shell-test 2>/dev/null || true)"
	[ "$code" = 403 ] && say "chunked upload refused (403)" || warn "chunked upload to 127.0.0.1 got HTTP ${code:-no answer}, expected 403 (fine if port 80 is not this Apache)"
fi
echo
if fixed; then
	if [ $APACHE -eq 1 ] || [ $FPM -eq 1 ]; then
		echo "DONE: PHP $(dpkg-query -W -f='${Version}' php7.3-common) has the php2shell fix and the web server is running it."
	else
		echo "DONE: PHP $(dpkg-query -W -f='${Version}' php7.3-common) has the php2shell fix. No PHP web server was running; it uses the fixed PHP when started."
	fi
	[ $LOCKED -eq 0 ] || echo "The lockdown is on as extra protection (remove it with: --rollback)."
	[ $BACKUP_ON -eq 0 ] || [ -z "$(ls "$BACKUP"/*.deb 2>/dev/null)" ] || echo "Old PHP saved in $BACKUP (put back with: --restore)."
	[ $WARN -eq 0 ] || echo "Some checks need a look - see the lines marked CHECK above."
	echo "Now open your site in a browser and check it works."
else
	die "PHP 7.3 does not have the fix"
fi
}
main "$@" < /dev/null
