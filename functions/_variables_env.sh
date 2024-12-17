function variables_env()
{
	local ENV="${1^^}"
	local VAR_DIR="${SCRIPT_DIR}"/../../"${CI_PROJECT_NAME}".tmp

	while IFS= read -r LINE; do
	if [[ "${LINE}" == "${DEPLOY_TYPE}"=* ]]; then
		DEPLOY_SERVICES="${LINE#*=}"
		IFS=' ' read -r -a DEPLOY_SERVICE <<< "${DEPLOY_SERVICES}"
	fi
	done < "${SCRIPT_DIR}"/../docker/variables/deployments

	## generate final mandatory variables file for selected deployment
	cat "${SCRIPT_DIR}"/../docker/variables/mandatory > "${STACK_FINAL_CONFIG_DIR}"/compose/variables.tmp

	pushd "${SCRIPT_DIR}"/../docker/template/variables &>/dev/null
	for t in "${DEPLOY_SERVICE[@]}"; do
		if [ -f "${SCRIPT_DIR}"/../docker/template/variables/"${t}"_template ]; then
			cat "${SCRIPT_DIR}"/../docker/template/variables/"${t}"_template >> "${STACK_FINAL_CONFIG_DIR}"/compose/variables.tmp
		fi
	done

	cat "${STACK_FINAL_CONFIG_DIR}"/compose/variables.tmp | sort | uniq > "${STACK_FINAL_CONFIG_DIR}"/compose/variables
	rm -f "${STACK_FINAL_CONFIG_DIR}"/compose/variables.tmp
	popd &>/dev/null

	## check and load ci environment file
	if [ ! -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_ENVIRONMENT_VARIABLES ] && [ ! -f "${VAR_DIR}"/"${ENV}"_STACK_ENVIRONMENT_VARIABLES ]; then
		echo "[GPD][ERROR] stack variables for environment ${ENVIRONMENT} do not exist"
		return 1
	elif [ ! -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_SECRETS ] && [ ! -f "${VAR_DIR}"/"${ENV}"_STACK_SECRETS ]; then
		echo "[GPD][ERROR] stack secrets variables for environment ${ENVIRONMENT} do not exist"
		return 1
	elif [ ! -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KEY ] && [ ! -f "${VAR_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KEY ] && [ ! "${ENVIRONMENT}" == "local" ]; then
		echo "[GPD][ERROR] stack deploy ssh key for environment ${ENVIRONMENT} does not exist"
		return 1
	elif [ ! -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS ] && [ ! -f "${VAR_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS ] && [ ! "${ENVIRONMENT}" == "local" ]; then
		echo "[GPD][ERROR] stack deploy ssh known hosts file for environment ${ENVIRONMENT} does not exist"
		return 1
	else
		if [ -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_ENVIRONMENT_VARIABLES ]; then
			source "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_ENVIRONMENT_VARIABLES
		else
			source "${VAR_DIR}"/"${ENV}"_STACK_ENVIRONMENT_VARIABLES
		fi

		if [ -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_SECRETS ]; then
			source "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_SECRETS
		else
			source "${VAR_DIR}"/"${ENV}"_STACK_SECRETS
		fi

		if [ -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KEY ]; then
			export "${ENV}"_STACK_DEPLOY_SSH_KEY="${ENV_CONFIG_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KEY
		else
			export "${ENV}"_STACK_DEPLOY_SSH_KEY="${VAR_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KEY
		fi

		if [ -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS ]; then
			export "${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS="${ENV_CONFIG_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS
		else
			export "${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS="${VAR_DIR}"/"${ENV}"_STACK_DEPLOY_SSH_KNOWN_HOSTS
		fi

		echo "[GPD][INFO] successfully loaded stack environment variables"

		return 0
	fi
}

function variables_env_check()
{
	STACK_VARIABLES=()
	while IFS= read -r LINE; do
		STACK_KEY="${LINE%%=*}"
		STACK_KEY="${STACK_KEY#"${STACK_KEY%%[![:space:]]*}"}"
		STACK_KEY="${STACK_KEY%"${STACK_KEY##*[![:space:]]}"}"
		STACK_VARIABLES+=("$STACK_KEY")
	done < "${STACK_FINAL_CONFIG_DIR}"/compose/variables

	STACK_VARIABLES_LEN=$(( "${#STACK_VARIABLES[@]}" - 1 ))

	## create array for the acme issue variable
	if [ -f "${SCRIPT_DIR}"/../docker/variables/acme ]; then
		STACK_ACME_VARIABLES=()
		while IFS= read -r LINE; do
			STACK_ACME_KEY="${LINE%%=*}"
			STACK_ACME_KEY="${STACK_ACME_KEY#"${STACK_ACME_KEY%%[![:space:]]*}"}"
			STACK_ACME_KEY="${STACK_ACME_KEY%"${STACK_ACME_KEY##*[![:space:]]}"}"
			STACK_ACME_VARIABLES+=("$STACK_ACME_KEY")
		done < "${SCRIPT_DIR}"/../docker/variables/acme

		STACK_ACME_VARIABLES_LEN=$(( "${#STACK_ACME_VARIABLES[@]}" - 1 ))
	fi

	## exit if necessary variables not set
	for i in `seq 0 "${STACK_VARIABLES_LEN}"`; do
		VAR=$(echo "${ENVIRONMENT^^}"_"${STACK_VARIABLES[$i]}")
		if [ -z "${!VAR}" ]; then
			echo "[GPD][ERROR] mandatory variable ${VAR} does not exist"
			return 1
		fi
	done

	return 0
}

function variables_env_replace()
{
	## replace with values from gitlabci webstats project settings
	for w in `seq 0 "${STACK_VARIABLES_LEN}"`; do
		STACK_VARIABLES_VAR=$(echo "${STACK_VARIABLES[$w]}")
		STACK_VARIABLES_REPLACE_VAR=$(echo "${ENVIRONMENT^^}"_"${STACK_VARIABLES[$w]}")
		echo "[GPD][GENERATE] replacing environment variable ${STACK_VARIABLES_REPLACE_VAR}"
		echo "${STACK_VARIABLES_VAR}=__${STACK_VARIABLES_VAR}__" >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack.env
		sed -i 's;__'${STACK_VARIABLES[$w]}'__;'"${!STACK_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack.env || return 1
		sed -i 's;__'${STACK_VARIABLES[$w]}'__;'"${!STACK_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack.yml || return 1
		sed -i 's;__'${STACK_VARIABLES[$w]}'__;'"${!STACK_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack-common.yml || return 1
		sed -i 's;__'${STACK_VARIABLES[$w]}'__;'"${!STACK_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack-extend.yml || return 1
		sed -i 's;__'${STACK_VARIABLES[$w]}'__;'"${!STACK_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/config/* || return 1
	done

	## add nginx server names to issue variable
	STACK_ACME_VAR1=${ENVIRONMENT^^}_STACK_ACME_VAR1
	STACK_ACME_ISSUE_OPTIONS_RSA=${ENVIRONMENT^^}_STACK_ACME_ISSUE_OPTIONS_RSA
	STACK_ACME_ISSUE_OPTIONS_ECC=${ENVIRONMENT^^}_STACK_ACME_ISSUE_OPTIONS_ECC

	if [ -f "${SCRIPT_DIR}"/../docker/variables/acme ] && [[ "${!STACK_ACME_VAR1}" =~ "ACME_EMPTY" ]]; then
		for w in `seq 0 "${STACK_ACME_VARIABLES_LEN}"`; do
			STACK_ACME_VARIABLES_REPLACE_VAR=$(echo "${ENVIRONMENT^^}"_"${STACK_ACME_VARIABLES[$w]}")
			STACK_ACME_NAMES+=($(echo "${!STACK_ACME_VARIABLES_REPLACE_VAR}"))
		done

		STACK_ACME_NAMES_ACME=( "${STACK_ACME_NAMES[@]/#/-d }" )

		echo "[GPD][GENERATE] rsa issue command: ${!STACK_ACME_ISSUE_OPTIONS_RSA} ${STACK_ACME_NAMES_ACME[@]}"
		echo "[GPD][GENERATE] ecc issue command: ${!STACK_ACME_ISSUE_OPTIONS_ECC} ${STACK_ACME_NAMES_ACME[@]}"
	else
		echo "[GPD][GENERATE] rsa issue command: ${!STACK_ACME_ISSUE_OPTIONS_RSA}"
		echo "[GPD][GENERATE] ecc issue command: ${!STACK_ACME_ISSUE_OPTIONS_ECC}"
	fi

	return 0
}
