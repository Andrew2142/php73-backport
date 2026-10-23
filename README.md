# php73-backport

[![verify](https://github.com/Andrew2142/php73-backport/actions/workflows/verify.yml/badge.svg)](https://github.com/Andrew2142/php73-backport/actions/workflows/verify.yml)
[![reproduce](https://github.com/Andrew2142/php73-backport/actions/workflows/reproduce.yml/badge.svg)](https://github.com/Andrew2142/php73-backport/actions/workflows/reproduce.yml)

PHP 7.3.33-35 (the php2shell fix, [CVE-2026-109618](https://www.cve.org/CVERecord?id=CVE-2026-109618) /
[CVE-2026-109619](https://www.cve.org/CVERecord?id=CVE-2026-109619)) rebuilt unchanged from
Ondřej Surý's source for systems his repos no longer cover. amd64 only.

| System | Installer |
|---|---|
| Ubuntu 18.04 | [`install-18.04.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-18.04.sh) |
| Ubuntu 20.04 | [`install-20.04.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh) |
| Debian 10 | [`install-debian-10.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-debian-10.sh) |

## Install

Download the script for your system and its signature:

```bash
# Ubuntu 18.04
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-18.04.sh
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-18.04.sh.asc

# Ubuntu 20.04
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh.asc

# Debian 10
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-debian-10.sh
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/install-debian-10.sh.asc
```

Verify and run (example for 18.04):

```bash
curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/php73-backport.asc | gpg --import
gpg --verify install-18.04.sh.asc install-18.04.sh
sudo bash install-18.04.sh       # --help for what it does
```

Key fingerprint: `9B95 FAF1 4F9E 8D38 793D  1E27 1725 6F38 D05B A5EF`. The key is also in this repo
([`php73-backport.asc`](php73-backport.asc)), on keyserver.ubuntu.com and on keys.openpgp.org.

It backs up your current PHP, upgrades only the PHP 7.3 packages you have, and restarts PHP-FPM /
Apache / nginx. The repo is apt-pinned to PHP 7.3 packages only. Undo with `--restore`.

## Don't trust us, check

php7.3 is built from Surý's source with no changes, and the build is reproducible: the same source always
gives byte-identical packages. These checks prove your files are exactly that. If one fails, don't install.

**Signature** (built into Ubuntu/Debian):

```bash
curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/php73-backport.asc | gpg --import
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/SHA256SUMS.asc
gpg --output SHA256SUMS --decrypt SHA256SUMS.asc   # Good signature, key 9B95 FAF1 … D05B A5EF
sha256sum -c --ignore-missing SHA256SUMS           # OK
```

**Built by GitHub** (optional, needs the [GitHub CLI](https://cli.github.com)). Works on any package; for
example, from a clone of this repo:

```bash
gh attestation verify php73-backport/dist/upload/focal/php7.3-fpm_7.3.33-35+ubuntu20.04.1+backport2_amd64.deb -R Andrew2142/php73-backport   # ✓ Verification succeeded!
```

Every package is [attested](https://github.com/Andrew2142/php73-backport/attestations) by the public
[reproduce](https://github.com/Andrew2142/php73-backport/actions/workflows/reproduce.yml) build and logged on
Sigstore's public log ([the entry for the example above](https://search.sigstore.dev/?logIndex=3428188866)).

**Rebuild it yourself** (optional, Docker, ~20 min):

```bash
git clone https://github.com/Andrew2142/php73-backport && cd php73-backport
bash reproduce.sh focal    # bionic / focal / buster; ends "byte-identical to the rebuild"
```

**Compare GitHub and DigitalOcean** (optional). The signing key and the list of every published file are kept
in both places, so you can check that they match.

```bash
# Checks that the signing key is the same on GitHub and DigitalOcean
curl -fsSL https://raw.githubusercontent.com/Andrew2142/php73-backport/main/php73-backport.asc -o key-github.asc
curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/php73-backport.asc -o key-digitalocean.asc
cmp key-github.asc key-digitalocean.asc && echo "same key"
gpg --show-keys key-github.asc
```

```bash
# Checks that every published file is the same on GitHub and DigitalOcean (run next to your clone)
curl -fsSL https://raw.githubusercontent.com/Andrew2142/php73-backport/main/dist/upload/SHA256SUMS -o sums-github
curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/SHA256SUMS -o sums-digitalocean
cmp sums-github sums-digitalocean && echo "same files"
(cd php73-backport/dist/upload && sha256sum -c ../../../sums-github)
```

The first should print `same key` and the fingerprint `9B95 FAF1 4F9E 8D38 793D  1E27 1725 6F38 D05B A5EF`. The
second should print `same files`, then `OK` for every file.

## Not covered

Other PHP versions, control-panel PHP (cPanel, Plesk, etc.), and CVE-2026-9672 (system libgd3).

## Build

```bash
bash build.sh bionic|focal|buster   # docker
bash publish.sh https://your.host/path
```

Security problems: see [SECURITY.md](SECURITY.md).

Not affiliated with Ondřej Surý, Debian, Ubuntu or PHP. MIT licensed, no warranty.

## Support Ondřej Surý

None of this exists without [Ondřej Surý](https://github.com/oerdnj), who has packaged PHP for Debian
and Ubuntu for years and backported the php2shell fix to PHP 7.3 for these packages. If this helped you,
go support him: [GitHub Sponsors](https://github.com/sponsors/oerdnj) ·
[Patreon](https://www.patreon.com/oerdnj) · [deb.sury.org](https://deb.sury.org/).
