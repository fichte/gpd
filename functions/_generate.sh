function generate()
{
	if ! variables_env "${ENVIRONMENT}"; then
		exit 1
	fi

	if ! variables_env_check; then
		exit 1
	fi

	if ! variables_ci "${ENVIRONMENT}"; then
		exit 1
	fi

	for i in diff find grep htpasswd perl rsync sha256sum sort ssh wget zstd
	do
		if ! check_binary "${i}"; then
			exit 1
		fi
	done

	if ! check_openssl; then
		exit 1
	fi

	echo "[GPD][GENERATE] starting config file generation"

	create_directories
	copy_config_files
	variables_base_replace

	if ! variables_env_replace; then
		exit 1
	fi

	if ! variables_ci_replace; then
		exit 1
	fi

	if [ -f "${STACK_FINAL_CONFIG_DIR}"/compose/nginx.yml ]; then
		if ! generate_admin_password; then
			exit 1
		fi
	fi

	if [ -f "${STACK_FINAL_CONFIG_DIR}"/compose/opensearch.yml ]; then
		if ! generate_opensearch_passwords; then
			exit 1
		fi
	fi

	if [ -f "${STACK_FINAL_CONFIG_DIR}"/compose/nginx.yml ]; then
		if ! generate_geoip; then
			exit 1
		fi
	fi

	if ! generate_env_file; then
		exit 1
	fi

	echo "[GPD][GENERATE] config file generation successful"
}
