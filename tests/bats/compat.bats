#!/usr/bin/env bats

# Verify _compat.sh fallback behaviour by masking the preferred tool.
# These tests skip rather than fail if no fallback is available on the
# host — they are about correctness *when* the fallback is used.

setup() {
	load 'helpers'
	source "${BATS_TEST_DIRNAME}/../../functions/_compat.sh"
}

@test "gpd_apr1_hash: htpasswd path produces $apr1$ format" {
	if ! command -v htpasswd >/dev/null 2>&1; then skip "htpasswd not installed"; fi
	out=$(gpd_apr1_hash 'plainpassword')
	[[ "${out}" =~ ^\$apr1\$ ]]
}

@test "gpd_apr1_hash: openssl fallback produces $apr1$ format" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not installed"; fi
	mask_htpasswd
	out=$(gpd_apr1_hash 'plainpassword')
	[[ "${out}" =~ ^\$apr1\$ ]]
}

@test "gpd_apr1_hash: handles password with shell metacharacters" {
	if ! command -v htpasswd >/dev/null 2>&1; then skip "htpasswd not installed"; fi
	out=$(gpd_apr1_hash 'p;a&s\swo$1$rd')
	[[ "${out}" =~ ^\$apr1\$ ]]
	# format invariant: no embedded newline, no leading "user:" prefix
	[[ "${out}" != *":"* ]]
	[ "$(printf '%s' "${out}" | wc -l | tr -d ' ')" = "0" ]
}

@test "gpd_bcrypt_hash: htpasswd path produces \$2y\$NN\$ format" {
	if ! command -v htpasswd >/dev/null 2>&1; then skip "htpasswd not installed"; fi
	out=$(gpd_bcrypt_hash 5 'plain')
	[[ "${out}" =~ ^\$2[ayb]\$05\$ ]]
}

@test "gpd_bcrypt_hash: python+bcrypt fallback produces bcrypt format" {
	if ! python3 -c 'import bcrypt' >/dev/null 2>&1; then skip "python3+bcrypt not installed"; fi
	mask_htpasswd
	out=$(gpd_bcrypt_hash 5 'plain')
	[[ "${out}" =~ ^\$2[ayb]\$05\$ ]]
}

@test "gpd_bcrypt_hash: errors with no bcrypt-capable tool" {
	mask_command htpasswd
	mask_command python3
	run gpd_bcrypt_hash 5 'plain'
	[ "${status}" -ne 0 ]
}

@test "gpd_htpasswd_create: htpasswd path writes valid file" {
	if ! command -v htpasswd >/dev/null 2>&1; then skip "htpasswd not installed"; fi
	tmp=$(mktemp)
	gpd_htpasswd_create "${tmp}" admin 'plain'
	[[ "$(cat "${tmp}")" =~ ^admin:\$apr1\$ ]]
	rm -f "${tmp}"
}

@test "gpd_htpasswd_create: openssl fallback writes admin:apr1 line" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not installed"; fi
	mask_htpasswd
	tmp=$(mktemp)
	gpd_htpasswd_create "${tmp}" admin 'plain'
	[[ "$(cat "${tmp}")" =~ ^admin:\$apr1\$ ]]
	rm -f "${tmp}"
}

@test "gpd_http_get: curl path downloads to a file" {
	if ! command -v curl >/dev/null 2>&1; then skip "curl not installed"; fi
	# We use a data: URL via a local file:// instead of hitting the network
	tmp_in=$(mktemp)
	echo "fixture-content" > "${tmp_in}"
	tmp_out=$(mktemp)
	gpd_http_get "file://${tmp_in}" "${tmp_out}"
	[ "$(cat "${tmp_out}")" = "fixture-content" ]
	rm -f "${tmp_in}" "${tmp_out}"
}

@test "gpd_retry: succeeds on first attempt without retrying" {
	gpd_retry 3 true
}

@test "gpd_retry: returns the inner failure exit status" {
	# `false` exits 1
	run gpd_retry 1 false
	[ "${status}" -eq 1 ]
}

@test "gpd_retry: succeeds on the third attempt" {
	# Counter file: increment on each invocation, succeed once it reaches 3.
	tmp=$(mktemp)
	echo 0 > "${tmp}"
	flaky() {
		local n
		n=$(<"${tmp}")
		n=$(( n + 1 ))
		echo "${n}" > "${tmp}"
		[ "${n}" -ge 3 ]
	}
	# Override sleep so the test doesn't actually wait 1+2 seconds.
	sleep() { :; }
	gpd_retry 5 flaky
	[ "$(cat "${tmp}")" -eq 3 ]
	rm -f "${tmp}"
}

@test "gpd_retry: gives up after MAX attempts" {
	tmp=$(mktemp)
	echo 0 > "${tmp}"
	always_fail() {
		local n
		n=$(<"${tmp}")
		echo "$(( n + 1 ))" > "${tmp}"
		return 7
	}
	sleep() { :; }
	run gpd_retry 4 always_fail
	[ "${status}" -eq 7 ]
	[ "$(cat "${tmp}")" -eq 4 ]
	rm -f "${tmp}"
}

@test "gpd_retry: COUNT < 1 still runs the command once" {
	gpd_retry 0 true
	run gpd_retry 0 false
	[ "${status}" -ne 0 ]
}

@test "gpd_silent: hides stdout and stderr but preserves exit status" {
	run gpd_silent bash -c 'echo out; echo err >&2; exit 42'
	[ "${status}" -eq 42 ]
	[ -z "${output}" ]
}
