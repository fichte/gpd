function check_openssl()
{
	if ! command -v openssl >/dev/null; then
		echo "[GPD][ERROR] binary: openssl not found"
		return 1
	fi

	local OPENSSL_VERSION
	# `grep -P` is a GNU extension that BSD grep on macOS lacks. Pull the
	# dotted-numeric prefix out via perl, which we already require.
	OPENSSL_VERSION=$(openssl version | perl -ne 'print $1 if /(\d+(?:\.\d+)+)/')

	if [[ "${OPENSSL_VERSION}" > "1.1.1" ]] || [[ "${OPENSSL_VERSION}" = "1.1.1" ]]; then
		echo "[GPD][INFO] using supported openssl version ${OPENSSL_VERSION}"
		return 0
	fi

	echo "[GPD][ERROR] openssl version ${OPENSSL_VERSION} not supported"
	return 1
}
