# tests

[bats](https://github.com/bats-core/bats-core) suite covering the substitution
helper, exact-match validation, the `_compat.sh` fallbacks, and an end-to-end
generate run against a self-contained fixture.

## Running

```bash
# macOS
brew install bats-core

# Debian / Ubuntu
apt-get install bats

# from the repo root
bats tests/bats/
```

A test that depends on a tool that isn't installed (e.g. `python3+bcrypt` for
the bcrypt fallback path) skips itself; failures only happen for genuine
regressions.

## What's covered

- `bats/substitute.bats` — `safe_replace_token` against every sed-killer and
  every perl replacement-string gotcha. Locks down the password-corruption fix.
- `bats/array_contains.bats` — exact-match membership, prevents the substring-
  regex regression.
- `bats/compat.bats` — every `_compat.sh` helper exercised in both its
  preferred and fallback path. Uses `mask_command` (in `helpers.bash`) to
  pretend a tool is missing.
- `bats/generate.bats` — end-to-end `gpd.sh -g` against
  `tests/fixtures/parent-stack/`. Asserts on substituted values, `stack.env`
  contents, exit codes for invalid input, and the absence of leftover
  `__TOKEN__` placeholders.

## Fixture layout

`tests/fixtures/parent-stack/` is a minimal but realistic parent project:

- One environment (`local`, which skips the SSH transport).
- One deploy-type (`minimal`) that selects one service (`service`).
- A compose template (`service.yml_template`) with placeholders for base, env,
  and CI variables.
- A config template (`service_main.conf_template`) that exercises the
  config-substitution path.
- A `LOCAL_STACK_ENVIRONMENT_VARIABLES` file containing a deliberately gnarly
  value (`p;a&s\swo$1$abc/def$2y$10$xyz`) so every regression in the
  substitution helper trips at least one assertion.

The fixture does **not** include `nginx.yml` or `opensearch.yml`, so the
password-generation and GeoIP-download paths don't fire — those are unit-tested
in `bats/compat.bats` instead.
