#!/usr/bin/env bash

# gpd_retry COUNT CMD [ARG...]
#
# Run CMD up to COUNT times until it succeeds. Sleeps with exponential
# backoff (1s, 2s, 4s, ...) between attempts, prints a one-line warning
# to stderr after each failed attempt, and returns the final exit status.
# COUNT below 1 is treated as 1 (single attempt, no retry).
function gpd_retry()
{
	local MAX="${1}"
	shift
	if [ "${MAX}" -lt 1 ]; then
		MAX=1
	fi

	local ATTEMPT RC SLEEP_FOR
	for (( ATTEMPT=1; ATTEMPT<=MAX; ATTEMPT++ )); do
		RC=0
		# Note: an `if cmd; then ...; fi` block masks the cmd's exit status
		# (bash spec: an if with no matching branch exits 0). The `||` form
		# preserves it and is also exempt from set -e.
		"$@" || RC=$?
		if [ "${RC}" -eq 0 ]; then
			return 0
		fi
		if [ "${ATTEMPT}" -lt "${MAX}" ]; then
			SLEEP_FOR=$(( 1 << (ATTEMPT - 1) ))
			echo "[GPD][RETRY] attempt ${ATTEMPT}/${MAX} failed (exit ${RC}), retrying in ${SLEEP_FOR}s" >&2
			sleep "${SLEEP_FOR}"
		fi
	done
	return "${RC}"
}

# gpd_silent CMD [ARG...]
#
# Run CMD with stdout and stderr both redirected to /dev/null. Useful as
# a wrapper for gpd_retry when the inner command is noisy and only the
# exit status matters: `gpd_retry 3 gpd_silent docker pull foo`.
function gpd_silent()
{
	"$@" >/dev/null 2>&1
}

# gpd_http_get URL OUTFILE
#
# Download URL to OUTFILE. Prefers curl (ships with macOS, almost every CI
# image). Falls back to wget. Both must be silent on success and exit
# non-zero on HTTP errors.
function gpd_http_get()
{
	local URL="${1}"
	local OUTFILE="${2}"

	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --retry 3 -o "${OUTFILE}" -- "${URL}"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "${OUTFILE}" -- "${URL}"
	else
		echo "[GPD][ERROR] need curl or wget to download ${URL}" >&2
		return 1
	fi
}

# gpd_bcrypt_hash COST PASSWORD
#
# Print a bcrypt ($2y$<cost>$...) hash for PASSWORD on stdout, no trailing
# newline. Prefers htpasswd (apache-utils on Debian/Ubuntu, /usr/sbin on
# macOS). Falls back to python3 with the bcrypt module.
function gpd_bcrypt_hash()
{
	local COST="${1}"
	local PASSWORD="${2}"

	if command -v htpasswd >/dev/null 2>&1; then
		htpasswd -bnBC "${COST}" "" "${PASSWORD}" | tr -d ':\n'
		return
	fi

	if command -v python3 >/dev/null 2>&1 && python3 -c 'import bcrypt' >/dev/null 2>&1; then
		GPD_BCRYPT_PWD="${PASSWORD}" python3 - "${COST}" <<'PY'
import bcrypt, os, sys
pw = os.environ["GPD_BCRYPT_PWD"].encode()
cost = int(sys.argv[1])
sys.stdout.write(bcrypt.hashpw(pw, bcrypt.gensalt(rounds=cost)).decode())
PY
		return
	fi

	echo "[GPD][ERROR] no bcrypt-capable tool found (need htpasswd or python3+bcrypt)" >&2
	return 1
}

# gpd_apr1_hash PASSWORD
#
# Print an apr1 ($apr1$salt$hash) hash for PASSWORD on stdout, no trailing
# newline. apr1 is the htpasswd MD5 variant used by WUD and the legacy
# nginx basic-auth file. Prefers htpasswd, falls back to openssl passwd.
function gpd_apr1_hash()
{
	local PASSWORD="${1}"

	if command -v htpasswd >/dev/null 2>&1; then
		# `htpasswd -nib admin <pwd>` outputs `admin:<hash>` — strip the prefix.
		htpasswd -nib admin "${PASSWORD}" | cut -d ':' -f 2- | tr -d '\n'
		return
	fi

	if command -v openssl >/dev/null 2>&1; then
		openssl passwd -apr1 -- "${PASSWORD}" | tr -d '\n'
		return
	fi

	echo "[GPD][ERROR] no apr1-capable tool found (need htpasswd or openssl)" >&2
	return 1
}

# gpd_htpasswd_create FILE USER PASSWORD
#
# Write a single-user htpasswd (apr1) file. Equivalent to
# `htpasswd -b -c FILE USER PASSWORD`, falls back to `openssl passwd -apr1`.
function gpd_htpasswd_create()
{
	local FILE="${1}"
	local USER="${2}"
	local PASSWORD="${3}"

	if command -v htpasswd >/dev/null 2>&1; then
		htpasswd -b -c "${FILE}" "${USER}" "${PASSWORD}" 2>/dev/null
		return
	fi

	local HASH
	HASH=$(gpd_apr1_hash "${PASSWORD}") || return 1
	printf '%s:%s\n' "${USER}" "${HASH}" >"${FILE}"
}
