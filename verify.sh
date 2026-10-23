#!/usr/bin/env bash
# Checks that the published files are what this repo says they are. Needs gpg, curl, sha256sum.
#
#   bash verify.sh              check dist/upload: signatures, checksums, apt metadata, and that
#                               source/ holds exactly the Sury files pinned in build.sh
#   bash verify.sh --upstream   also re-download those source files from packages.sury.org and compare
#   bash verify.sh --release    also download the GitHub release and compare it with dist/upload
#   bash verify.sh --hosted     also download every file from the hosted repo and compare it with dist/upload
#   bash verify.sh --all        all of the above
#
# Exits non-zero on the first mismatch.

set -euo pipefail
cd "$(dirname "$0")"

FPR=9B95FAF14F9E8D38793D1E2717256F38D05BA5EF
REPO=Andrew2142/php73-backport
TAG=7.3.33-35-backport2
HOSTED=https://php73-backport.fra1.digitaloceanspaces.com
SURY=https://packages.sury.org/php/pool/main/p
U=dist/upload

UPSTREAM=0 RELEASE=0 HOST=0
for a in "$@"; do
	case "$a" in
		--upstream) UPSTREAM=1 ;;
		--release)  RELEASE=1 ;;
		--hosted)   HOST=1 ;;
		--all)      UPSTREAM=1 RELEASE=1 HOST=1 ;;
		*) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
	esac
done

ok()   { echo "  ok    $*"; }
fail() { echo "  FAIL  $*"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export GNUPGHOME="$T/gnupg"; mkdir -m 700 "$GNUPGHOME"

echo "signing key"
gpg -q --import php73-backport.asc 2>/dev/null
gpg --with-colons --list-keys | grep -q "^fpr:::::::::$FPR:" || fail "php73-backport.asc is not $FPR"
cmp -s php73-backport.asc "$U/php73-backport.asc" || fail "$U/php73-backport.asc differs from php73-backport.asc"
ok "php73-backport.asc is $FPR"
sigok() { gpg --status-fd 1 --verify "$@" 2>/dev/null | grep -q "^\[GNUPG:\] VALIDSIG $FPR "; }
sumsok() { # SHA256SUMS.asc is either a detached signature or a clearsigned copy of SHA256SUMS
	if head -1 "$1.asc" | grep -q 'SIGNED MESSAGE'; then
		sigok "$1.asc" && gpg -q --decrypt "$1.asc" 2>/dev/null | cmp -s - "$1"
	else
		sigok "$1.asc" "$1"
	fi
}

echo "dist/upload"
sumsok "$U/SHA256SUMS" || fail "SHA256SUMS signature"
ok "SHA256SUMS signed by $FPR"
( cd "$U" && sha256sum -c --quiet SHA256SUMS ) || fail "SHA256SUMS"
listed=$(sed 's/^[0-9a-f]*  \.\///' "$U/SHA256SUMS" | sort)
present=$(cd "$U" && find . -type f ! -name 'SHA256SUMS*' | sed 's#^\./##' | sort)
[ "$listed" = "$present" ] || fail "files in $U do not match SHA256SUMS: $(diff <(echo "$listed") <(echo "$present") | grep '^[<>]' | head -5 | tr '\n' ' ')"
ok "all $(echo "$present" | wc -l) files match SHA256SUMS, nothing extra or missing"
for s in "$U"/install-*.sh; do
	sigok "$s.asc" "$s" || fail "$s signature"
done
ok "installers signed by $FPR"

for c in bionic focal buster; do
	sigok "$U/$c/InRelease" || fail "$c/InRelease signature"
	sigok "$U/$c/Release.gpg" "$U/$c/Release" || fail "$c/Release.gpg signature"
	# every index file listed under SHA256 in Release must match
	awk '/^SHA256:/{f=1;next} /^[^ ]/{f=0} f{print $1"  "$3}' "$U/$c/Release" | grep -v '  Release$' \
		| ( cd "$U/$c" && sha256sum -c --quiet ) || fail "$c/Release hashes"
	# every .deb in Packages must match, and every .deb on disk must be in Packages
	awk '/^Filename:/{f=$2} /^SHA256:/{print $2"  "f}' "$U/$c/Packages" | sed -E "s#  (\./)?$c/#  #; s#  \./#  #" \
		| ( cd "$U/$c" && sha256sum -c --quiet ) || fail "$c/Packages hashes"
	[ "$(grep -c '^Filename:' "$U/$c/Packages")" = "$(ls "$U/$c"/*.deb | wc -l)" ] || fail "$c has .debs not in Packages"
	! ls "$U/$c"/php-common_*.deb >/dev/null 2>&1 || fail "$c ships php-common"
	ok "$c apt repo: signed, $(ls "$U/$c"/*.deb | wc -l) packages match Packages"
done

echo "source"
grep -o 'fetch "[^"]*" *[0-9a-f]\{64\}' build.sh | sed 's/fetch "//; s/" */ /' > "$T/pins"
PHP_V=$(sed -n 's/^PHP_V=//p' build.sh); DEF_V=$(sed -n 's/^DEF_V=//p' build.sh)
while read -r path sum; do
	path=${path//\$PHP_V/$PHP_V}; path=${path//\$DEF_V/$DEF_V}; f=$(basename "$path")
	echo "$sum  $U/source/$f" | sha256sum -c --quiet 2>/dev/null || fail "source/$f does not match build.sh"
	echo "$path $sum" >> "$T/pins.resolved"
done < "$T/pins"
ok "source/ holds the $(wc -l < "$T/pins") Sury files pinned in build.sh"
for f in build.sh in-container.sh install.sh.in; do
	cmp -s "$f" "$U/source/$f" || fail "source/$f differs from $f in this repo"
done
ok "source/ build scripts match this repo"

if [ "$UPSTREAM" = 1 ]; then
	echo "upstream (packages.sury.org)"
	while read -r path sum; do
		curl -fsSL "$SURY/${path//+/%2B}" -o "$T/up" || fail "download $SURY/$path"
		echo "$sum  $T/up" | sha256sum -c --quiet 2>/dev/null || fail "Sury's $(basename "$path") has changed"
	done < "$T/pins.resolved"
	ok "all $(wc -l < "$T/pins.resolved") source files are byte-identical to packages.sury.org"
fi

if [ "$RELEASE" = 1 ]; then
	echo "GitHub release $TAG"
	R=https://github.com/$REPO/releases/download/$TAG
	mkdir "$T/rel"
	for f in SHA256SUMS SHA256SUMS.asc; do curl -fsSL "$R/$f" -o "$T/rel/$f" || fail "download $f"; done
	sumsok "$T/rel/SHA256SUMS" || fail "release SHA256SUMS signature"
	for f in $(awk '{print $2}' "$T/rel/SHA256SUMS"); do curl -fsSL "$R/$f" -o "$T/rel/$f" || fail "download $f"; done
	( cd "$T/rel" && sha256sum -c --quiet SHA256SUMS ) || fail "release SHA256SUMS"
	for f in install-18.04.sh install-18.04.sh.asc install-20.04.sh install-20.04.sh.asc \
	         install-debian-10.sh install-debian-10.sh.asc php73-backport.asc; do
		cmp -s "$T/rel/$f" "$U/$f" || fail "release $f differs from $U/$f"
	done
	for c in bionic focal buster; do
		tar xzf "$T/rel/php73-backport-$c-amd64.tar.gz" -C "$T/rel"
		diff -r "$T/rel/$c" "$U/$c" >/dev/null || fail "release tarball for $c differs from $U/$c"
	done
	tar xzf "$T/rel/source.tar.gz" -C "$T/rel"
	for f in "$U"/source/*; do
		b=$(basename "$f"); [ "$b" = publish.sh ] && continue
		cmp -s "$f" "$T/rel/source/$b" || fail "release source.tar.gz $b differs"
	done
	ok "signed, and every asset matches dist/upload"
fi

if [ "$HOST" = 1 ]; then
	echo "hosted repo $HOSTED"
	n=0
	while read -r sum f; do
		f=${f#./}
		curl -fsSL "$HOSTED/${f//+/%2B}" -o "$T/h" || fail "download $f"
		echo "$sum  $T/h" | sha256sum -c --quiet 2>/dev/null || fail "hosted $f differs"
		n=$((n + 1))
	done < "$U/SHA256SUMS"
	for f in SHA256SUMS SHA256SUMS.asc; do
		curl -fsSL "$HOSTED/$f" -o "$T/h" && cmp -s "$T/h" "$U/$f" || fail "hosted $f differs"
	done
	ok "all $n hosted files match dist/upload"
fi

echo "all checks passed"
