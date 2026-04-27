#!/usr/bin/env bats

setup() {
	load 'helpers'
	source "${BATS_TEST_DIRNAME}/../../functions/_substitute.sh"
	TMP=$(mktemp -d)
}

teardown() {
	rm -rf "${TMP}"
}

@test "safe_replace_token: basic replacement" {
	echo 'hello __NAME__' > "${TMP}/f"
	safe_replace_token "NAME" "world" "${TMP}/f"
	assert_file_eq "${TMP}/f" 'hello world'
}

@test "safe_replace_token: value containing semicolons" {
	echo '__VAL__' > "${TMP}/f"
	safe_replace_token "VAL" "a;b;c" "${TMP}/f"
	assert_file_eq "${TMP}/f" 'a;b;c'
}

@test "safe_replace_token: value containing ampersand" {
	echo '__VAL__' > "${TMP}/f"
	safe_replace_token "VAL" "a&b&c" "${TMP}/f"
	assert_file_eq "${TMP}/f" 'a&b&c'
}

@test "safe_replace_token: value containing backslashes" {
	echo '__VAL__' > "${TMP}/f"
	safe_replace_token "VAL" 'a\b\c' "${TMP}/f"
	assert_file_eq "${TMP}/f" 'a\b\c'
}

@test "safe_replace_token: value containing forward slashes" {
	echo '__VAL__' > "${TMP}/f"
	safe_replace_token "VAL" 'a/b/c' "${TMP}/f"
	assert_file_eq "${TMP}/f" 'a/b/c'
}

@test "safe_replace_token: bcrypt-shaped value with dollar sequences" {
	echo '__HASH__' > "${TMP}/f"
	safe_replace_token "HASH" '$2y$10$abcdEFGH/ijklMNOP.qrstUVwxYZ0123456789AbCdEf' "${TMP}/f"
	assert_file_eq "${TMP}/f" '$2y$10$abcdEFGH/ijklMNOP.qrstUVwxYZ0123456789AbCdEf'
}

@test "safe_replace_token: apr1-shaped value" {
	echo '__HASH__' > "${TMP}/f"
	safe_replace_token "HASH" '$apr1$WJ/twELE$ksP272jymtanzYZ4m8TTq/' "${TMP}/f"
	assert_file_eq "${TMP}/f" '$apr1$WJ/twELE$ksP272jymtanzYZ4m8TTq/'
}

@test "safe_replace_token: composite gnarly password" {
	echo '__P__' > "${TMP}/f"
	safe_replace_token "P" 'p;a&s\swo\nrd $1$abc/def$2y$10$xyz' "${TMP}/f"
	assert_file_eq "${TMP}/f" 'p;a&s\swo\nrd $1$abc/def$2y$10$xyz'
}

@test "safe_replace_token: multiple files at once" {
	echo '__X__' > "${TMP}/a"
	echo '__X__' > "${TMP}/b"
	safe_replace_token "X" "yes" "${TMP}/a" "${TMP}/b"
	assert_file_eq "${TMP}/a" 'yes'
	assert_file_eq "${TMP}/b" 'yes'
}

@test "safe_replace_token: multiple occurrences in one file" {
	printf '%s\n' '__X__' '__X__' '__X__' > "${TMP}/f"
	safe_replace_token "X" "v" "${TMP}/f"
	[ "$(cat "${TMP}/f")" = "$(printf '%s\n' v v v)" ]
}

@test "safe_replace_token: skips directories silently" {
	mkdir "${TMP}/sub"
	echo '__X__' > "${TMP}/f"
	safe_replace_token "X" "ok" "${TMP}/f" "${TMP}/sub"
	assert_file_eq "${TMP}/f" 'ok'
}

@test "safe_replace_token: zero files is a no-op (returns 0)" {
	run safe_replace_token "X" "v"
	[ "${status}" -eq 0 ]
}

@test "safe_replace_token: empty token errors out" {
	echo 'x' > "${TMP}/f"
	run safe_replace_token "" "v" "${TMP}/f"
	[ "${status}" -ne 0 ]
}

@test "safe_replace_token: token only matches __TOKEN__, not bare TOKEN" {
	printf '%s\n' '__NAME__ + NAME + _NAME_' > "${TMP}/f"
	safe_replace_token "NAME" "x" "${TMP}/f"
	assert_file_eq "${TMP}/f" 'x + NAME + _NAME_'
}

@test "safe_replace_token: token with regex metacharacters in name is treated literally" {
	# Sanity: even though . and * are regex metas, the helper escapes the token
	# before matching. (We never use regex tokens in practice, but the helper
	# should be safe.)
	echo '__A.B__' > "${TMP}/f"
	safe_replace_token "A.B" "ok" "${TMP}/f"
	assert_file_eq "${TMP}/f" 'ok'
	# A.B should NOT match anything else
	echo '__AXB__' > "${TMP}/f"
	safe_replace_token "A.B" "ok" "${TMP}/f"
	assert_file_eq "${TMP}/f" '__AXB__'
}
