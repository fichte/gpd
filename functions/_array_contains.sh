#!/usr/bin/env bash

# array_contains NEEDLE ELEMENT [ELEMENT...]
#
# Returns 0 if NEEDLE matches one of the ELEMENTS exactly. The previous
# substring-regex check (`[[ "${arr[@]}" =~ "${needle}" ]]`) accepted
# `"rod"` as a match for `"prod"`; this helper does an exact comparison.
function array_contains()
{
	local NEEDLE="${1}"
	shift
	local ELEMENT
	for ELEMENT in "$@"; do
		if [ "${ELEMENT}" = "${NEEDLE}" ]; then
			return 0
		fi
	done
	return 1
}
