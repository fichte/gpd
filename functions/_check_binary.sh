function check_binary()
{
	local BINARY="${1}"

	if ! which "${BINARY}" &>/dev/null; then
		echo "[GPD][ERROR] binary: ${BINARY} not found"
		return 1
	else
		echo "[GPD][INFO] binary: ${BINARY} found"
	fi
}
