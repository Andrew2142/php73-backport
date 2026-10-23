# php73-backport

PHP 7.3.33-35 (the php2shell fix, CVE-2026-109618 / CVE-2026-109619) rebuilt unchanged from
Ondřej Surý's source for systems his repos no longer cover. amd64 only.

| System | Installer |
|---|---|
| Ubuntu 18.04 | [`install-18.04.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-18.04.sh) |
| Ubuntu 20.04 | [`install-20.04.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh) |
| Debian 10 | [`install-debian-10.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-debian-10.sh) |

## Install

```bash
S=install-18.04.sh   # or install-20.04.sh / install-debian-10.sh
B=https://php73-backport.fra1.digitaloceanspaces.com
curl -fsSLO $B/$S && curl -fsSLO $B/$S.asc
curl -fsSL $B/php73-backport.asc | gpg --import
gpg --verify $S.asc $S
sudo bash $S         # --help for what it does
```

Key fingerprint: `9B95 FAF1 4F9E 8D38 793D  1E27 1725 6F38 D05B A5EF`

It backs up your current PHP, upgrades only the PHP 7.3 packages you have, and restarts PHP-FPM /
Apache / nginx. The repo is apt-pinned to PHP 7.3 packages only. Undo with `--restore`.

## Not covered

Other PHP versions, control-panel PHP (cPanel, Plesk, etc.), and CVE-2026-9672 (system libgd3).

## Build

```bash
bash build.sh bionic|focal|buster   # docker
bash publish.sh https://your.host/path
```

Not affiliated with Ondřej Surý, Debian, Ubuntu or PHP. MIT licensed, no warranty.
