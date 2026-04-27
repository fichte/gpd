# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.2] - 2026-04-27

### Changed
- `functions/_deploy.sh` (`deploy_logout_from_registry`): joins the
  retry'd flaky-network operations. `docker logout` now retries up to
  `--retries` times with exponential backoff, same wrapper as login,
  pull, push, and GeoIP download.

## [1.0.1] - 2026-04-27

### Fixed
- `functions/_remove_unused_images.sh`: refactor onto `run_in_target` /
  `compose_in_target`, replace BSD-incompatible `seq 0 N-1` loops with
  array iteration, and drop the tangled-quoting `sed '/v/d'` pipelines
  that were producing empty output over SSH on real remote hosts. Also
  switches to `--format '{{.Repository}}:{{.Tag}}'` to avoid fragile
  column parsing.

## [1.0.0] - 2026-04-27

### Added
- `functions/_substitute.sh` (`safe_replace_token`) — perl-based placeholder
  substitution that treats values as opaque strings. Replaces `sed -i 's;__VAR__;…;g'`
  call sites that silently corrupted compose/config files when values contained
  `;`, `&`, `\`, `$1`, or `$2y$10$…`.
- `functions/_array_contains.sh` — exact-match membership test, replaces the
  substring-regex check that allowed e.g. `"rod"` to validate against `"prod"`.
- `functions/_compat.sh` (`gpd_http_get`, `gpd_bcrypt_hash`, `gpd_apr1_hash`,
  `gpd_htpasswd_create`) — portable wrappers with fallbacks (curl→wget,
  htpasswd→python3+bcrypt, htpasswd→openssl-apr1).
- `functions/_gpd.sh` (`run_in_target`, `compose_in_target`) — collapse the
  duplicated local-vs-remote branches in `_deploy.sh` onto a single helper
  pair. Args are shell-quoted with `printf %q` for SSH transport.
- `gpd.sh`: explicit Bash 4+ assertion on startup with a `brew install bash` hint.
- `gpd.sh`: inline `gpd_realpath` helper that works on macOS and Git-Bash.
- README: full parent-project layout contract, flag reference, and platform
  notes.
- CHANGELOG (this file).
- `tests/`: bats suite covering substitution, exact-match validation, every
  `_compat.sh` fallback path, and an end-to-end generate run against
  `tests/fixtures/parent-stack/`. 40 cases, runs on Linux and macOS.
- `.github/workflows/test.yml`: CI matrix (Ubuntu + macOS) running bats and
  shellcheck on every push/PR.
- `-r/--retries=<N>` flag (default 3) wrapping the four flaky-network
  operations: rsync push, registry login, image pull, and GeoIP
  download. Backoff between attempts is exponential (1s, 2s, 4s, …)
  via the new `gpd_retry` helper in `functions/_compat.sh`.

### Changed
- `gpd.sh`: invalid `--deploy-type` now exits with status 1 instead of
  printing an error and continuing.
- `functions/_check_binary.sh`: portable `command -v` instead of `which`.
- `functions/_check_openssl.sh`: drop `eval $(which openssl)`; require openssl
  via the binary check first.
- `functions/_generate_passwords.sh`: compose `$ → $$` doubling done in pure
  bash parameter expansion instead of an extra `sed` pipe.
- `functions/include.sh`: use `BASH_SOURCE[0]` instead of `readlink -e $0`.
- `functions/_deploy.sh`: refactored from 333 to 232 lines. Every dual-branch
  (local-vs-remote) collapsed onto `compose_in_target`/`run_in_target`. The
  `if ! $(cmd &>/dev/null)` pattern (which preserved exit status only by
  accident, when stdout happened to be empty) replaced with the obvious
  `if ! cmd >/dev/null 2>&1`. Fixed a copy-paste typo where the
  no-registry detection checked `CI_REGISTRY_USER` twice instead of
  `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD`.
- `functions/_deploy.sh` (`deploy_dry_run`): retries 3× with exponential
  backoff (1 / 2 / 4 s) and a fatal-pattern grep over stderr, so genuine
  config errors (`access denied`, `manifest unknown`, …) fail fast instead
  of burning every retry.

### Removed
- Hard runtime dependency on `htpasswd` and `wget`. Both are still preferred
  when present, but the script can run without them.
- `_usage.sh`: `-l/--docker-login` and `-k/--docker-logout` flags. They were
  parsed but never read — login/logout already happen inline in
  `_deploy.sh`.

[Unreleased]: https://github.com/fichte/gpd/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/fichte/gpd/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/fichte/gpd/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fichte/gpd/releases/tag/v1.0.0
