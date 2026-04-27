function deploy_init()
{
	DEPLOY_STACK_ENV_FILE="${BASEDIR}"/"${ENVIRONMENT}"/.env

	if [[ "${ENVIRONMENT}" == local* ]]; then
		unset DOCKER_HOST
	fi

	while IFS= read -r LINE; do
	if [[ "${LINE}" == "${DEPLOY_TYPE}"=* ]]; then
		DEPLOY_SERVICES="${LINE#*=}"
		IFS=' ' read -r -a DEPLOY_SERVICE <<< "${DEPLOY_SERVICES}"
	fi
	done < "${SCRIPT_DIR}"/../docker/variables/deployments

	DEPLOY_SERVICE_LEN=$(( "${#DEPLOY_SERVICE[@]}" ))

	echo "[GPD][DEPLOY] starting deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]}"
	gpd init

	if [ -f "${SCRIPT_DIR}"/../docker/variables/side ]; then
		DEPLOY_SIDE_STACK=()
		while IFS= read -r LINE; do
			DEPLOY_SIDE_STACK+=("${LINE}")
		done < "${SCRIPT_DIR}"/../docker/variables/side

		DEPLOY_SIDE_STACK_FINAL=()

		local SIDE_STACK SIDE_STACK_DIR SIDE_ENV_FILE
		for SIDE_STACK in "${DEPLOY_SIDE_STACK[@]}"; do
			SIDE_STACK_DIR="${BASEDIR}"/../"${SIDE_STACK}"
			SIDE_ENV_FILE="${SIDE_STACK_DIR}"/"${ENVIRONMENT}"/.env
			if run_in_target test -f "${SIDE_ENV_FILE}"; then
				echo "[GPD][DEPLOY][INFO] include side stack: ${SIDE_STACK}"
				DEPLOY_SIDE_STACK_FINAL+=("${SIDE_STACK}")
			else
				echo "[GPD][DEPLOY][WARNING] side stack: ${SIDE_STACK} defined but not deployed"
			fi
		done
	fi
}

function deploy_check_initial()
{
	if [[ "${ENVIRONMENT}" == local* ]] && [ ! "${DEPLOY_TYPE}" == "full" ] && [ ! -d "${BASEDIR}"/"${ENVIRONMENT}"/data/acme ]; then
		echo "[GPD][DEPLOY][ERROR] no acme data directory found please use deploy-type full for initial deployment"
		exit 1
	fi
}

function deploy_check_running()
{
	if [ "${DEPLOY_FORCE}" == "true" ]; then
		echo "[GPD][DEPLOY][WARNING] ignore check running of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]}"
		return 0
	fi

	local RUNNING_COUNT
	RUNNING_COUNT=$(compose_in_target "${DEPLOY_STACK_ENV_FILE}" ps --services --status running -q "${DEPLOY_SERVICE[@]}" | wc -l | tr -d '[:space:]')

	if [ "${RUNNING_COUNT}" -ne "${DEPLOY_SERVICE_LEN}" ]; then
		echo "[GPD][DEPLOY][ERROR] not all services are running, preventing deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]}"
		return 1
	fi

	return 0
}

function deploy_login_to_registry()
{
	if [ -z "${CI_REGISTRY}" ]; then
		echo "[GPD][DEPLOY][ERROR] no registry set, set CI_REGISTRY variable"
		exit 1
	fi

	if [ -z "${CI_REGISTRY_USER}" ]; then
		echo "[GPD][DEPLOY][ERROR] no user set, set CI_REGISTRY_USER variable"
		exit 1
	fi

	if [ -z "${CI_REGISTRY_PASSWORD}" ]; then
		echo "[GPD][DEPLOY][ERROR] no password set, set CI_REGISTRY_PASSWORD variable"
		exit 1
	fi

	if [[ "${CI_REGISTRY}" == "null" && "${CI_REGISTRY_USER}" == "null" && "${CI_REGISTRY_PASSWORD}" == "null" ]]; then
		echo "[GPD][DEPLOY] no registry defined, assuming all images in public registries"
		return 0
	fi

	if ! gpd_retry "${RETRIES}" gpd_silent run_in_target docker login -u "${CI_REGISTRY_USER}" -p "${CI_REGISTRY_PASSWORD}" "${CI_REGISTRY}"; then
		echo "[GPD][DEPLOY][ERROR] login to registry failed after ${RETRIES} attempts"
		return 1
	fi

	echo "[GPD][DEPLOY] login to registry successful"
	return 0
}

function deploy_pull_images()
{
	if ! gpd_retry "${RETRIES}" gpd_silent compose_in_target "${DEPLOY_STACK_ENV_FILE}" pull -q "${DEPLOY_SERVICE[@]}"; then
		echo "[GPD][DEPLOY][ERROR] pulling images failed after ${RETRIES} attempts"
		return 1
	fi

	echo "[GPD][DEPLOY] pulling images successful"
	return 0
}

# Strings that mean "this dry-run failure is the user's fault, not the
# network's". When we see one of these in stderr, fail fast instead of
# burning retries.
DEPLOY_DRY_RUN_FATAL_PATTERNS='access denied|repository does not exist|manifest unknown|unauthorized|not found:|pull access denied|invalid reference format|service ".*" depends on undefined service'

function deploy_dry_run()
{
	local MAX_RETRIES=3
	local STDERR_LOG
	STDERR_LOG=$(mktemp)
	local ATTEMPT SLEEP_FOR

	for ATTEMPT in $(seq 1 "${MAX_RETRIES}"); do
		if compose_in_target "${DEPLOY_STACK_ENV_FILE}" up --detach --dry-run --force-recreate --no-color "${DEPLOY_SERVICE[@]}" >/dev/null 2>"${STDERR_LOG}"; then
			rm -f "${STDERR_LOG}"
			echo "[GPD][DEPLOY] dry run successful, continuing deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]}"
			return 0
		fi

		if grep -Eqi "${DEPLOY_DRY_RUN_FATAL_PATTERNS}" "${STDERR_LOG}"; then
			echo "[GPD][DEPLOY][ERROR] dry run failed with non-transient error:" >&2
			cat "${STDERR_LOG}" >&2
			rm -f "${STDERR_LOG}"
			[ "${DEPLOY_FORCE}" == "true" ] && {
				echo "[GPD][DEPLOY][WARNING] force flag set, ignoring fatal dry-run error"
				return 0
			}
			return 1
		fi

		if [ "${ATTEMPT}" -lt "${MAX_RETRIES}" ]; then
			SLEEP_FOR=$(( 1 << (ATTEMPT - 1) ))
			echo "[GPD][DEPLOY][WARNING] dry run attempt ${ATTEMPT}/${MAX_RETRIES} failed (transient), retrying in ${SLEEP_FOR}s"
			sleep "${SLEEP_FOR}"
		fi
	done

	if [ "${DEPLOY_FORCE}" == "true" ]; then
		echo "[GPD][DEPLOY][WARNING] ignore dry run of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]}"
		rm -f "${STDERR_LOG}"
		return 0
	fi

	echo "[GPD][DEPLOY][ERROR] dry run failed after ${MAX_RETRIES} retries:" >&2
	cat "${STDERR_LOG}" >&2
	rm -f "${STDERR_LOG}"
	return 1
}

function deploy_on_target()
{
	if ! compose_in_target "${DEPLOY_STACK_ENV_FILE}" up --detach --force-recreate --no-color "${DEPLOY_SERVICE[@]}" >/dev/null 2>&1; then
		echo "[GPD][DEPLOY][ERROR] deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]} failed"
		return 1
	fi

	echo "[GPD][DEPLOY] deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[*]} successful"
	return 0
}

function deploy_logout_from_registry()
{
	if [ -z "${CI_REGISTRY}" ]; then
		echo "[GPD][DEPLOY][ERROR] no registry set, set CI_REGISTRY variable"
		exit 1
	fi

	if [[ "${CI_REGISTRY}" == "null" ]]; then
		return 0
	fi

	if ! run_in_target docker logout "${CI_REGISTRY}" >/dev/null 2>&1; then
		echo "[GPD][DEPLOY][ERROR] logout from registry failed"
		return 1
	fi

	echo "[GPD][DEPLOY] logout from registry successful"
	return 0
}

function deploy_check_main()
{
	read -r DEPLOY_MAIN_STACK < "${SCRIPT_DIR}"/../docker/variables/main
	DEPLOY_MAIN_STACK_ENV_FILE="${BASEDIR}"/../"${DEPLOY_MAIN_STACK}"/"${ENVIRONMENT}"/.env

	if ! run_in_target test -f "${DEPLOY_MAIN_STACK_ENV_FILE}"; then
		echo "[GPD][DEPLOY][ERROR] main stack: ${DEPLOY_MAIN_STACK} not deployed"
		return 1
	fi

	local RUNNING_COUNT TOTAL_COUNT
	RUNNING_COUNT=$(compose_in_target "${DEPLOY_MAIN_STACK_ENV_FILE}" ps -a -q --status=running | wc -l | tr -d '[:space:]')
	TOTAL_COUNT=$(compose_in_target "${DEPLOY_MAIN_STACK_ENV_FILE}" config --services | wc -l | tr -d '[:space:]')

	if [ "${RUNNING_COUNT}" -ne "${TOTAL_COUNT}" ]; then
		echo "[GPD][DEPLOY][ERROR] not all services of main stack: ${DEPLOY_MAIN_STACK} are running"
		return 1
	fi

	echo "[GPD][DEPLOY][INFO] all services of main stack: ${DEPLOY_MAIN_STACK} are running, continuing deployment"
	return 0
}

function deploy_side_down()
{
	local SIDE_STACK SIDE_ENV_FILE RUNNING_COUNT
	for SIDE_STACK in "${DEPLOY_SIDE_STACK_FINAL[@]}"; do
		SIDE_ENV_FILE="${BASEDIR}"/../"${SIDE_STACK}"/"${ENVIRONMENT}"/.env
		RUNNING_COUNT=$(compose_in_target "${SIDE_ENV_FILE}" ps -a -q --status=running | wc -l | tr -d '[:space:]')

		if [ "${RUNNING_COUNT}" -eq 0 ]; then
			echo "[GPD][DEPLOY] side stack: ${SIDE_STACK} already stopped"
		else
			echo "[GPD][DEPLOY] stop side stack: ${SIDE_STACK}"
			compose_in_target "${SIDE_ENV_FILE}" down >/dev/null 2>&1
		fi
	done
}

function deploy_side_up()
{
	local SIDE_STACK SIDE_ENV_FILE
	for SIDE_STACK in "${DEPLOY_SIDE_STACK_FINAL[@]}"; do
		SIDE_ENV_FILE="${BASEDIR}"/../"${SIDE_STACK}"/"${ENVIRONMENT}"/.env

		if ! compose_in_target "${SIDE_ENV_FILE}" up -d >/dev/null 2>&1; then
			echo "[GPD][DEPLOY][ERROR] deploy side stack: ${SIDE_STACK} failed"
			return 1
		fi

		echo "[GPD][DEPLOY] deployment of side stack: ${SIDE_STACK} successful"
	done
}

function deploy()
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

	deploy_init
	deploy_check_initial

	if ! deploy_check_running; then
		exit 1
	fi

	if ! deploy_login_to_registry; then
		exit 1
	fi

	if ! deploy_pull_images; then
		exit 1
	fi

	if ! deploy_logout_from_registry; then
		exit 1
	fi

	if ! deploy_dry_run; then
		exit 1
	fi

	if [ -f "${SCRIPT_DIR}"/../docker/variables/main ]; then
		if ! deploy_check_main; then
			exit 1
		fi
	fi

	# TODO: rollback on partial deploy failure (e.g. side_down succeeds, deploy_on_target fails).
	# Today we proceed even if a side stack fails to come back up; the half-applied state stays.
	if [ "${#DEPLOY_SIDE_STACK_FINAL[@]}" -gt 0 ]; then
		deploy_side_down
	elif [ ! -f "${SCRIPT_DIR}"/../docker/variables/main ]; then
		echo "[GPD][DEPLOY][INFO] not stopping any side stacks"
	fi

	if ! deploy_on_target; then
		exit 1
	fi

	if [ "${#DEPLOY_SIDE_STACK_FINAL[@]}" -gt 0 ]; then
		if ! deploy_side_up; then
			exit 1
		fi
	elif [ ! -f "${SCRIPT_DIR}"/../docker/variables/main ]; then
		echo "[GPD][DEPLOY][INFO] not deploying any side stacks"
	fi
}
