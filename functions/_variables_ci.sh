function variables_ci()
{
	local ENV="${1^^}"

	STACK_CI_VARIABLES=("CI_REGISTRY" "CI_PROJECT_PATH" "CI_COMMIT_REF_NAME" "CI_COMMIT_SHORT_SHA")
	STACK_CI_VARIABLES_LEN=$(( "${#STACK_CI_VARIABLES[@]}" - 1 ))

	## check and load ci environment file
	if [ ! -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_CI_VARIABLES ] && [ ! -f "${ENV}"_STACK_CI_VARIABLES ]; then
		echo "[GPD][INFO] assuming running in CI mode"
	else
		echo "[GPD][INFO] running in non CI mode"
		if [ -f "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_CI_VARIABLES ]; then
			source "${ENV_CONFIG_DIR}"/"${ENV}"_STACK_CI_VARIABLES
		else
			source "${ENV}"_STACK_CI_VARIABLES
		fi
	fi

	if [ -z "${CI_REGISTRY}" ]; then
		echo "[GPD][ERROR] variable CI_REGISTRY not set"
		exit 1
	else
		echo "[GPD][INFO] using registry \"${CI_REGISTRY}\""
	fi

	if [ -z "${CI_PROJECT_PATH}" ]; then
		echo "[GPD][ERROR] variable CI_PROJECT_PATH not set"
		exit 1
	else
		echo "[GPD][INFO] using project path \"${CI_PROJECT_PATH}\""
	fi

	if [ -z "${CI_COMMIT_REF_NAME}" ]; then
		if ! git symbolic-ref --short HEAD &>/dev/null; then
			CI_COMMIT_REF_NAME=$(git describe --all | cut -f2- -d "/")
			CI_COMMIT_REF_NAME_MESSAGE="using tag"
		else
			CI_COMMIT_REF_NAME=$(git symbolic-ref --short HEAD 2>/dev/null | sed -e 's/\//_/g')
			CI_COMMIT_REF_NAME_MESSAGE="using branch"
		fi

		if [ -z "${CI_COMMIT_REF_NAME}" ]; then
			echo "[GPD][ERROR] variable CI_COMMIT_REF_NAME not set"
			exit 1
		else
			echo "[GPD][INFO] ${CI_COMMIT_REF_NAME_MESSAGE} \"${CI_COMMIT_REF_NAME}\""
		fi
	fi

	if [ -z "${CI_COMMIT_SHORT_SHA}" ]; then
		CI_COMMIT_SHORT_SHA=$(git rev-parse --short=8 HEAD)

		if [ -z "${CI_COMMIT_SHORT_SHA}" ]; then
			echo "[GPD][ERROR] variable CI_COMMIT_SHORT_SHA not set"
			exit 1
		else
			echo "[GPD][INFO] using commit \"${CI_COMMIT_SHORT_SHA}\""
		fi
	fi
}

function variables_ci_replace()
{
	if [[ "${CI_COMMIT_REF_NAME}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		CI_COMMIT_SHORT_SHA="${CI_COMMIT_REF_NAME}"
	else
		CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME}/${CI_PROJECT_NAME}"
	fi

	if [[ "${CI_COMMIT_REF_NAME}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		CI_COMMIT_REF_NAME="release/${CI_PROJECT_NAME}"
	fi

	## replace with values from gitlabci default exported variables
	for c in `seq 0 "${STACK_CI_VARIABLES_LEN}"`; do
		STACK_CI_VARIABLES_VAR=$(echo "${STACK_CI_VARIABLES[$c]}")
		STACK_CI_VARIABLES_REPLACE_VAR=$(echo "${STACK_CI_VARIABLES[$c]}")
		echo "[GPD][GENERATE] replacing ci variable ${STACK_CI_VARIABLES_REPLACE_VAR}"
		echo "${STACK_CI_VARIABLES_VAR}=__${STACK_CI_VARIABLES_VAR}__" >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack.env
		sed -i 's;__'${STACK_CI_VARIABLES[$c]}'__;'"${!STACK_CI_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack.env
		sed -i 's;__'${STACK_CI_VARIABLES[$c]}'__;'"${!STACK_CI_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack.yml
		sed -i 's;__'${STACK_CI_VARIABLES[$c]}'__;'"${!STACK_CI_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack-common.yml
		sed -i 's;__'${STACK_CI_VARIABLES[$c]}'__;'"${!STACK_CI_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/compose/stack-extend.yml
		sed -i 's;__'${STACK_CI_VARIABLES[$c]}'__;'"${!STACK_CI_VARIABLES_REPLACE_VAR}"';g' "${STACK_FINAL_CONFIG_DIR}"/config/*
	done
}
