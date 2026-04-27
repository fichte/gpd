#!/usr/bin/env bats

setup() {
	source "${BATS_TEST_DIRNAME}/../../functions/_array_contains.sh"
}

@test "array_contains: exact match returns 0" {
	array_contains "prod" "stage" "prod" "local"
}

@test "array_contains: substring is NOT a match" {
	! array_contains "rod" "stage" "prod" "local"
}

@test "array_contains: empty needle is NOT matched against non-empty arr" {
	! array_contains "" "stage" "prod" "local"
}

@test "array_contains: empty needle IS matched if array contains empty string" {
	# Arguments include an empty element
	array_contains "" "a" "" "b"
}

@test "array_contains: zero-length array returns 1" {
	! array_contains "anything"
}

@test "array_contains: needle with whitespace must match exactly" {
	array_contains "two words" "one" "two words" "three"
	! array_contains "two words" "one" "two_words" "three"
}

@test "array_contains: needle with shell metacharacters" {
	array_contains 'p;a$b' 'safe' 'p;a$b' 'other'
	! array_contains 'p;a$b' 'safe' 'pXaXb' 'other'
}

@test "array_contains: trailing whitespace is significant" {
	# array entries have leading/trailing space, needle does not — must not match
	! array_contains "prod" "prod " " prod" "prodprod"
}

@test "array_contains: works in single-element arrays" {
	array_contains "only" "only"
	! array_contains "absent" "only"
}
