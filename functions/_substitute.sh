#!/usr/bin/env bash

# safe_replace_token TOKEN VALUE FILE [FILE...]
#
# Replace every literal occurrence of __TOKEN__ with VALUE in each FILE.
# The value is treated as an opaque string — characters that are special to
# sed (`;`, `&`, `\`, newline) or to perl replacement strings (`$1`, `${...}`)
# are inserted verbatim. Directories and missing paths are silently skipped.
function safe_replace_token()
{
	local TOKEN="${1}"
	local VALUE="${2}"
	shift 2

	if [ -z "${TOKEN}" ]; then
		echo "[GPD][ERROR] safe_replace_token called without a token" >&2
		return 1
	fi

	local FILES=()
	local F
	for F in "$@"; do
		[ -f "${F}" ] && FILES+=("${F}")
	done

	if [ "${#FILES[@]}" -eq 0 ]; then
		return 0
	fi

	GPD_TOKEN="__${TOKEN}__" GPD_VALUE="${VALUE}" perl -i -pe '
		BEGIN { $t = $ENV{GPD_TOKEN}; $v = $ENV{GPD_VALUE} }
		s/\Q$t\E/$v/ge
	' "${FILES[@]}"
}
