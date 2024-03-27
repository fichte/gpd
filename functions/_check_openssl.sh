function check_openssl()
{
	OPENSSL_VERSION=$(eval $(which openssl) version | cut -f 2 -d " " | grep -Po "(\d+\.)+\d+")

	if [[ "${OPENSSL_VERSION}" > "1.1.1" ]] || [[ "${OPENSSL_VERSION}" = "1.1.1" ]]; then
		echo "[GPD][INFO] using supported openssl version ${OPENSSL_VERSION}"
		return 0
	else
		echo "[GPD][ERROR] openssl version ${OPENSSL_VERSION} not supported"
		return 1
	fi
}
