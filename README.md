# php73-backport

PHP 7.3.33-35 — the fix for **php2shell** (CVE-2026-109618 / CVE-2026-109619) — rebuilt for the
systems Ondřej Surý's repositories no longer cover:

| System | PHP 7.3 comes from | Installer |
|---|---|---|
| Ubuntu 18.04 (bionic) | `ppa:ondrej/php` | [`install-18.04.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-18.04.sh) |
| Ubuntu 20.04 (focal) | `ppa:ondrej/php` | [`install-20.04.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-20.04.sh) |
| Debian 10 (buster) | Debian itself (7.3.31) | [`install-debian-10.sh`](https://php73-backport.fra1.digitaloceanspaces.com/install-debian-10.sh) |

amd64 only. Ubuntu 22.04/24.04 and Debian 11–13 do not need this: the fix is already in
`ppa:ondrej/php` / `packages.sury.org`.

This is an independent rebuild. It is not affiliated with or endorsed by Ondřej Surý, Debian, Ubuntu
or the PHP project. Please do not report problems with these packages to them.

## Quick start

Verify, read, then run:

```bash
S=install-18.04.sh   # or install-20.04.sh / install-debian-10.sh
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/$S
curl -fsSLO https://php73-backport.fra1.digitaloceanspaces.com/$S.asc
curl -fsSL https://php73-backport.fra1.digitaloceanspaces.com/php73-backport.asc | gpg --import
gpg --verify $S.asc $S          # must say "Good signature", fingerprint below
less $S
sudo bash $S                    # asks before each step; --yes for no questions, --help for details
```

Signing key fingerprint: **`9B95 FAF1 4F9E 8D38 793D  1E27 1725 6F38 D05B A5EF`**
(also in [`php73-backport.asc`](php73-backport.asc) in this repo).

## What the installer does

In order, stopping before any change if a check fails:

0. **Checks** — root, the right OS, amd64, PHP 7.3 installed from apt, no half-installed or held
   PHP packages, disk space, no apt run in progress. Notes control panels whose own PHP it does not
   touch. Shows what it found and the plan, and asks.
1. **Repo** — adds the signed apt repo, **pinned so it can only ever supply PHP 7.3 packages**
   (`/etc/apt/preferences.d/php73-backport.pref`). Checks a fixed build exists for every PHP 7.3
   package you have; if not, removes the repo again and stops.
2. **Backup** — saves your current PHP packages with `dpkg-repack` to
   `/var/backups/php73-pre-backport`, so `--restore` can put them back exactly.
3. **Update** — upgrades only the PHP 7.3 packages already installed. Nothing new installed, nothing
   removed, config files kept, `php-common` left alone (so php-imagick, php-redis etc. keep working).
   Puts back any Apache module the upgrade toggled. Verifies the fix is in the package changelog and
   that every extension that loaded before (ionCube, imagick, ...) still loads — if not, it stops
   before restarting anything.
4. **Lockdown** (optional, `--no-lockdown`) — upload progress off; request body cap of 32MB or your
   `post_max_size`, whichever is bigger; multipart uploads without `Content-Length` refused (Apache).
5. **Restart** — PHP-FPM 7.3, Apache, nginx (whichever run), then checks nothing still runs the old
   PHP. Long-running CLI workers are listed for you to restart.

Other options: `--rollback` (remove lockdown), `--remove-repo` (keep fixed PHP, drop the repo),
`--restore` (old PHP back), `--no-backup`. Full text: `bash install-18.04.sh --help`.

Works with Apache mod_php, Apache + PHP-FPM, nginx + PHP-FPM, CLI-only, and without systemd.

## Not covered

- PHP versions other than 7.3, and non-amd64 servers.
- PHP shipped by control panels (cPanel `ea-php73`, Plesk, DirectAdmin, aaPanel, LiteSpeed `lsphp73`)
  or compiled by hand — get the fix from that vendor.
- **CVE-2026-9672** (libgd GIF decoder overflow). Surý's -35 patches PHP's *bundled* libgd, but
  Debian/Ubuntu PHP packages link the *system* libgd3, which Ubuntu has not fixed for any release
  and Debian 10 only in paid ELTS. Avoid decoding untrusted GIFs with gd.
- Debian 10 ELTS (Freexian) customers: check whether your ELTS PHP already has the fix.

## How it is built

`build.sh <codename>` downloads Surý's `php7.3_7.3.33-35` and `php-defaults_101` source packages
from `packages.sury.org` (pinned by SHA-256), checks every Surý patch applies, and builds them
unchanged in a clean `ubuntu:18.04` / `ubuntu:20.04` / `debian:10` container. Only the version
suffix and changelog entry change (`+ubuntu18.04.1+backport1` etc.). The build environment's own
`php-common` is used, so the telemetry build flags in Surý's newer `php-common.mk` are not compiled
in; the build fails if they are.

`php-common` is built but not published: Surý's newer one declares `Breaks` on older PECL
packages and would remove them, and every PHP 7.3 system already has one new enough.

For Debian 10, Debian's own unchanged `dpkg-repack` and `libdpkg-perl` are added to the repo,
because most buster servers' apt sources no longer resolve and the backup step needs them.

```bash
bash build.sh bionic          # needs docker; ~15 min each
bash build.sh focal
bash build.sh buster
bash publish.sh https://your.host/path    # signed flat apt repos + installers in dist/upload/
```

`publish.sh` signs with the key in `~/.php73-backport-gnupg`; use your own key to host your own
copy. `test/` holds the container fixtures used to test the installer (a stock Debian 10 PHP 7.3,
and a relabelled "old" PHP for Ubuntu, since the PPA no longer serves bionic/focal builds).

## Layout of the hosted repo

```
install-18.04.sh  install-20.04.sh  install-debian-10.sh   (+ .asc signatures)
php73-backport.asc                 public key
SHA256SUMS  SHA256SUMS.asc         checksums of everything, signed
bionic/  focal/  buster/           flat apt repos (InRelease signed)
source/                            the exact Surý source used + these build scripts
```

The same files are attached to each [GitHub release](../../releases).

## License

The scripts in this repository are MIT licensed (see [LICENSE](LICENSE)). PHP is under the
PHP License; Surý's Debian packaging under its own terms (see `debian/copyright` in the source).
No warranty: test on a non-production server first and keep backups.
