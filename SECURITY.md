# Security

Report a problem with these packages, the installers or the signing key privately through
[GitHub's private vulnerability reporting](https://github.com/Andrew2142/php73-backport/security/advisories/new).
Please don't open a public issue for it.

Bugs in PHP itself belong upstream: [php.net](https://www.php.net/) for PHP, and
[Ondřej Surý's tracker](https://github.com/oerdnj/deb.sury.org/issues) for the Debian packaging.
These builds take the fixes Surý publishes, rebuilt unchanged.

All files are signed with this key and nothing else:

    9B95 FAF1 4F9E 8D38 793D  1E27 1725 6F38 D05B A5EF

If a file is signed by any other key, don't install it. `bash verify.sh --all` checks everything
that has been published.
