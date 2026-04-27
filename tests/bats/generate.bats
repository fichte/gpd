#!/usr/bin/env bats

# End-to-end smoke test for `gpd.sh -g`. Sets up a self-contained parent
# project from tests/fixtures/parent-stack and runs the generate stage
# against it, then asserts the rendered files have the expected content
# and contain no leftover __VAR__ tokens.

setup() {
	GPD_ROOT="${BATS_TEST_DIRNAME}/../.."
	FIXTURE="${BATS_TEST_DIRNAME}/../fixtures/parent-stack"
	PARENT="${BATS_TEST_TMPDIR}/parent"
	# Replicate fixture into a writable parent dir, then drop the gpd repo
	# alongside as a sibling to docker/. Real usage embeds gpd as a submodule;
	# we copy its source files instead of symlinking so realpath() in gpd.sh
	# still resolves to a path with docker/ as a sibling.
	mkdir -p "${PARENT}/gpd/functions"
	cp -R "${FIXTURE}/docker" "${PARENT}/"
	cp "${GPD_ROOT}/gpd.sh" "${PARENT}/gpd/"
	cp -R "${GPD_ROOT}/functions/." "${PARENT}/gpd/functions/"
	# Local* env doesn't need an SSH key; nothing else to set up.
}

@test "generate: minimal fixture renders without leftover tokens" {
	cd "${PARENT}"
	run bash gpd/gpd.sh -e local -t minimal -b /tmp/gpd-test -g
	[ "${status}" -eq 0 ]

	# Output tree exists
	[ -d "${PARENT}/docker/final/local/asset" ]
	[ -d "${PARENT}/docker/final/local/compose" ]
	[ -d "${PARENT}/docker/final/local/config" ]
	[ -d "${PARENT}/docker/final/local/data" ]

	# No leftover __TOKEN__ placeholders in any rendered file
	! grep -rn '__[A-Z_]\+__' "${PARENT}/docker/final/local/compose" "${PARENT}/docker/final/local/config"
}

@test "generate: ordinary substitution lands the right values" {
	cd "${PARENT}"
	bash gpd/gpd.sh -e local -t minimal -b /tmp/gpd-test -g

	# Plain string substitution
	grep -F 'GREETING=hello world' "${PARENT}/docker/final/local/compose/service.yml"
	grep -Fx 'greeting = hello world' "${PARENT}/docker/final/local/config/service_main.conf"

	# Base variable substitution
	grep -F 'ENV=LOCAL' "${PARENT}/docker/final/local/compose/service.yml"
	grep -F 'name: local-test' "${PARENT}/docker/final/local/compose/service.yml"
	grep -F '/tmp/gpd-test/local/data/service:/data' "${PARENT}/docker/final/local/compose/service.yml"

	# CI variable substitution
	grep -F 'REGISTRY=registry.example.com' "${PARENT}/docker/final/local/compose/service.yml"
}

@test "generate: gnarly password-shaped value lands verbatim" {
	cd "${PARENT}"
	bash gpd/gpd.sh -e local -t minimal -b /tmp/gpd-test -g

	# The value `p;a&s\swo$1$abc/def$2y$10$xyz` exercises every sed-killer
	# (;, &, \) plus the perl replacement-string gotchas ($1, $2y, $10).
	# In the COMPOSE file we don't double dollars (only password helpers do
	# that), so the value should appear verbatim.
	grep -F 'GNARLY=p;a&s\swo$1$abc/def$2y$10$xyz' "${PARENT}/docker/final/local/compose/service.yml"
	grep -Fx 'gnarly = p;a&s\swo$1$abc/def$2y$10$xyz' "${PARENT}/docker/final/local/config/service_main.conf"
}

@test "generate: stack.env carries the substituted values" {
	cd "${PARENT}"
	bash gpd/gpd.sh -e local -t minimal -b /tmp/gpd-test -g

	# stack.env is built with __TOKEN__ placeholders and then runs through
	# the same substitution pass as the rest of compose/, so it ends up with
	# the real values (handy as a single-file env source for docker compose).
	grep -Fx 'STACK_GREETING=hello world' "${PARENT}/docker/final/local/compose/stack.env"
	grep -Fx 'STACK_GNARLY_VALUE=p;a&s\swo$1$abc/def$2y$10$xyz' "${PARENT}/docker/final/local/compose/stack.env"
	grep -Fx 'STACK_ENV=LOCAL' "${PARENT}/docker/final/local/compose/stack.env"
	grep -Fx 'CI_REGISTRY=registry.example.com' "${PARENT}/docker/final/local/compose/stack.env"
}

@test "generate: invalid environment exits non-zero" {
	cd "${PARENT}"
	run bash gpd/gpd.sh -e nonexistent -t minimal -b /tmp/gpd-test -g
	[ "${status}" -ne 0 ]
}

@test "generate: invalid deploy-type exits non-zero (no fall-through)" {
	cd "${PARENT}"
	run bash gpd/gpd.sh -e local -t bogus -b /tmp/gpd-test -g
	[ "${status}" -ne 0 ]
	# Should NOT see the "starting config file generation" message
	! grep -q "starting config file generation" <<< "${output}"
}

@test "generate: substring environment is rejected" {
	cd "${PARENT}"
	# "loca" is a substring of "local" but should not pass exact-match validation
	run bash gpd/gpd.sh -e loca -t minimal -b /tmp/gpd-test -g
	[ "${status}" -ne 0 ]
}
