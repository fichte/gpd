function check_binary()
{
	local BINARY="${1}"

	if ! command -v "${BINARY}" >/dev/null; then
		echo "[GPD][ERROR] binary: ${BINARY} not found"
		return 1
	fi

	echo "[GPD][INFO] binary: ${BINARY} found"
}
