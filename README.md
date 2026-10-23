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

php7.3 is built from Surý's source with no changes; only the version suffix differs. The build is
reproducible, so you can check that yourself:

```bash
bash verify.sh --all        # signatures, checksums, source identical to packages.sury.org, release = hosted files
bash reproduce.sh focal     # rebuild here (docker, ~20 min) and compare every published .deb byte for byte
gh attestation verify php7.3-fpm_7.3.33-35+ubuntu20.04.1+backport2_amd64.deb -R Andrew2142/php73-backport
```

The last one shows the file was built by the public
[reproduce](https://github.com/Andrew2142/php73-backport/actions/workflows/reproduce.yml) workflow on
GitHub's runners. That workflow rebuilds all three systems on every change and monthly, and fails if a
single byte differs.

## Not covered

Other PHP versions, control-panel PHP (cPanel, Plesk, etc.), and CVE-2026-9672 (system libgd3).

## Build

```bash
bash build.sh bionic|focal|buster   # docker
bash publish.sh https://your.host/path
```

Security problems: see [SECURITY.md](SECURITY.md).

Not affiliated with Ondřej Surý, Debian, Ubuntu or PHP. MIT licensed, no warranty.
