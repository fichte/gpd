function variables_base()
{
	STACK_ENVIRONMENT_DEPLOY_SSH_KEY="${ENVIRONMENT^^}"_STACK_DEPLOY_SSH_KEY
	STACK_ENVIRONMENT_DEPLOY_SSH_KNOWN_HOSTS="${ENVIRONMENT^^}"_STACK_DEPLOY_SSH_KNOWN_HOSTS
	STACK_ENVIRONMENT_VARIABLES="${ENVIRONMENT^^}"_STACK_ENVIRONMENT_VARIABLES
	STACK_ENV="${ENVIRONMENT^^}"
	STACK_ENV_LOWER="${ENVIRONMENT}"
	STACK_PATH="${BASEDIR}/${ENVIRONMENT}"
	STACK_ASSET_PATH="${STACK_PATH}/asset"
	STACK_COMPOSE_PATH="${STACK_PATH}/compose"
	STACK_CONFIG_PATH="${STACK_PATH}/config"
	STACK_DATA_PATH="${STACK_PATH}/data"
	STACK_FINAL_CONFIG_DIR="${SCRIPT_DIR}"/../docker/final/"${ENVIRONMENT}"

	if [ ! -f "${SCRIPT_DIR}"/../docker/variables/name ]; then
		echo "[GPD][ERROR] file "${SCRIPT_DIR}"/../docker/variables/name which should contain the stack name does not exist"
		exit 1
	else
		STACK_NAME_FILE="${SCRIPT_DIR}"/../docker/variables/name

		if [ ! $(wc -l < "${STACK_NAME_FILE}") -eq 1 ]; then
			echo "[GPD][ERROR] file "${SCRIPT_DIR}"/../docker/variables/name should contain exactly one line with the stack name"
			exit 1
		else
			IFS= read -r STACK_NAME_LINE_ONE < "${STACK_NAME_FILE}"
			STACK_NAME="${STACK_NAME_LINE_ONE}"
		fi
	fi
}

function variables_base_replace()
{
	local STACK_BASE_VARIABLES_KEY=("STACK_ENV" "STACK_ENV_LOWER" "STACK_PATH" "STACK_ASSET_PATH" "STACK_COMPOSE_PATH" "STACK_CONFIG_PATH" "STACK_DATA_PATH")
	local KEY

	for KEY in "${STACK_BASE_VARIABLES_KEY[@]}"; do
		echo "[GPD][GENERATE] replacing base variable ${KEY}"
		echo "${KEY}=__${KEY}__" >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack.env
		safe_replace_token "${KEY}" "${!KEY}" "${STACK_FINAL_CONFIG_DIR}"/compose/* "${STACK_FINAL_CONFIG_DIR}"/config/*
	done
}

function create_directories()
{
	echo "[GPD][GENERATE] create directory ${STACK_FINAL_CONFIG_DIR}/asset"
	mkdir -p "${STACK_FINAL_CONFIG_DIR}"/asset
	echo "[GPD][GENERATE] create directory ${STACK_FINAL_CONFIG_DIR}/compose"
	mkdir -p "${STACK_FINAL_CONFIG_DIR}"/compose
	echo "[GPD][GENERATE] create directory ${STACK_FINAL_CONFIG_DIR}/config"
	mkdir -p "${STACK_FINAL_CONFIG_DIR}"/config
	echo "[GPD][GENERATE] create directory ${STACK_FINAL_CONFIG_DIR}/data"
	mkdir -p "${STACK_FINAL_CONFIG_DIR}"/data
}
