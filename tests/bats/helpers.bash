#!/usr/bin/env bash

# Shared bats helpers. Sourced via `load 'helpers'` from .bats files.

# assert_file_eq FILE EXPECTED_CONTENT
# Compares FILE's content (stripping a single trailing newline) to EXPECTED_CONTENT.
assert_file_eq() {
	local file="${1}"
	local expected="${2}"
	local actual
	actual=$(<"${file}")
	if [ "${actual}" != "${expected}" ]; then
		printf 'expected: %q\n' "${expected}" >&2
		printf 'actual:   %q\n' "${actual}" >&2
		return 1
	fi
}

# mask_command CMD [CMD ...]
# Make `command -v CMD` return 1 for the named tools, leaving other lookups
# intact. Used to force the fallback path in compat tests. Repeated calls
# accumulate; bats runs each @test in its own subshell so the masking auto-
# resets between tests.
GPD_TEST_MASKED=()
mask_command() {
	GPD_TEST_MASKED+=("$@")
	command() {
		if [ "${1}" = "-v" ]; then
			local _t
			for _t in "${GPD_TEST_MASKED[@]}"; do
				[ "${_t}" = "${2}" ] && return 1
			done
		fi
		builtin command "$@"
	}
}

# mask_htpasswd: shorthand for the most common case.
mask_htpasswd() {
	mask_command htpasswd
}
