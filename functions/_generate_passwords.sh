function generate_admin_password()
{
	echo "[GPD][GENERATE] generating stack admin management password"
	local ADMIN_PASSWORD_VAR="${ENVIRONMENT^^}_STACK_ADMIN_MANAGEMENT_PASSWORD"
	local ADMIN_PASSWORD="${!ADMIN_PASSWORD_VAR}"

	if ! gpd_htpasswd_create "${STACK_FINAL_CONFIG_DIR}"/config/nginx_nginxpasswd admin "${ADMIN_PASSWORD}"; then
		echo "[GPD][GENERATE][ERROR] generating stack admin management password failed"
		return 1
	fi

	## passwords destined for compose files double every $ so docker-compose
	## does not treat them as variable references
	local WUD_PASSWORD PORTAINER_PASSWORD STACK_ADMIN_PASSWORD STACK_ADMIN_10_PASSWORD
	WUD_PASSWORD=$(gpd_apr1_hash "${ADMIN_PASSWORD}") || return 1
	WUD_PASSWORD="${WUD_PASSWORD//\$/\$\$}"
	PORTAINER_PASSWORD=$(gpd_bcrypt_hash 5 "${ADMIN_PASSWORD}") || return 1
	PORTAINER_PASSWORD="${PORTAINER_PASSWORD//\$/\$\$}"
	STACK_ADMIN_PASSWORD=$(gpd_bcrypt_hash 8 "${ADMIN_PASSWORD}") || return 1
	STACK_ADMIN_10_PASSWORD=$(gpd_bcrypt_hash 10 "${ADMIN_PASSWORD}") || return 1

	safe_replace_token "WUD_PASSWORD" "${WUD_PASSWORD}" "${STACK_FINAL_CONFIG_DIR}"/compose/*
	safe_replace_token "PORTAINER_PASSWORD" "${PORTAINER_PASSWORD}" "${STACK_FINAL_CONFIG_DIR}"/compose/*
	safe_replace_token "STACK_ADMIN_PASSWORD" "${STACK_ADMIN_PASSWORD}" "${STACK_FINAL_CONFIG_DIR}"/config/*
	safe_replace_token "STACK_ADMIN_10_PASSWORD" "${STACK_ADMIN_10_PASSWORD}" "${STACK_FINAL_CONFIG_DIR}"/config/*
	echo "[GPD][GENERATE] generating stack admin management password successful"
	return 0
}

function generate_opensearch_passwords()
{
	echo "[GPD][GENERATE] generating opensearch passwords"

	local OPENSEARCH_USERS=()
	local LINE OPENSEARCH_USER

	while IFS= read -r LINE; do
		if [[ "${LINE}" == *OPENSEARCH*PASSWORD* ]]; then
			OPENSEARCH_USER="${LINE#*OPENSEARCH_}"
			OPENSEARCH_USER="${OPENSEARCH_USER%%_PASSWORD*}"
			OPENSEARCH_USERS+=("${OPENSEARCH_USER}")
		fi
	done < "${STACK_FINAL_CONFIG_DIR}"/compose/variables

	local USER ENV_PASSWORD_VAR HASHED_PASSWORD
	for USER in "${OPENSEARCH_USERS[@]}"; do
		ENV_PASSWORD_VAR="${ENVIRONMENT^^}_STACK_OPENSEARCH_${USER}_PASSWORD"
		HASHED_PASSWORD=$(gpd_bcrypt_hash 12 "${!ENV_PASSWORD_VAR}") || return 1
		safe_replace_token "OPENSEARCH_${USER}_PASSWORD" "${HASHED_PASSWORD}" "${STACK_FINAL_CONFIG_DIR}"/config/*
	done

	echo "[GPD][GENERATE] generating opensearch passwords successful"
}
