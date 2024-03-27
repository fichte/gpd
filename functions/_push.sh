function push()
{
	if ! variables_env "${ENVIRONMENT}"; then
		exit 1
	fi

	if ! variables_env_check; then
		exit 1
	fi

	if [ ! -f "${STACK_FINAL_CONFIG_DIR}"/.env ]; then
		echo "[GPD][ERROR] configuration files for environment ${ENVIRONMENT} do not exist, please generate first"
		exit 1
	elif gpd diffenv "${STACK_FINAL_CONFIG_DIR}" "${BASEDIR}"; then
		STACK_SHA=$(grep COMPOSE_STACK_SHA "${STACK_FINAL_CONFIG_DIR}"/.env | cut -f 2 -d "=")
		echo "[GPD][WARNING] config files for environment ${ENVIRONMENT} already pushed"
		return 0
	else
		gpd rsync "${STACK_FINAL_CONFIG_DIR}" "${BASEDIR}"
		if [ ! "${ENVIRONMENT}" == "local" ] && { [ ! -f "${SCRIPT_DIR}"/../docker/variables/side ] && [ ! -f "${SCRIPT_DIR}"/../docker/variables/main ]; }; then
			echo "[GPD][PUSH] creating symbolic link from ${BASEDIR}/${ENVIRONMENT}/.env to ~/.ssh/environment for user ${!STACK_DEPLOY_USER}"
			gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'ln -sf '"${BASEDIR}"'/'"${ENVIRONMENT}"'/.env ~/.ssh/environment'
		fi
	fi
}
