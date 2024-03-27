function deploy_init()
{
	DEPLOY_STACK_ENV_FILE="${BASEDIR}"/"${ENVIRONMENT}"/.env

	if [ "${ENVIRONMENT}" == "local" ]; then
		unset DOCKER_HOST
	fi

	while IFS= read -r LINE; do
	if [[ "${LINE}" == "${DEPLOY_TYPE}"=* ]]; then
		DEPLOY_SERVICES="${LINE#*=}"
		IFS=' ' read -r -a DEPLOY_SERVICE <<< "${DEPLOY_SERVICES}"
	fi
	done < "${SCRIPT_DIR}"/../docker/variables/deployments

	DEPLOY_SERVICE_LEN=$(( "${#DEPLOY_SERVICE[@]}" ))
	DEPLOY_SERVICE_REMOTE=$(echo "${DEPLOY_SERVICE[@]}")

	echo "[GPD][DEPLOY] starting deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]}"
	gpd init

	if [ -f "${SCRIPT_DIR}"/../docker/variables/side ]; then
		DEPLOY_SIDE_STACK=()
		while IFS= read -r LINE; do
			DEPLOY_SIDE_STACK+=("${LINE}")
		done < "${SCRIPT_DIR}"/../docker/variables/side

		DEPLOY_SIDE_STACK_LEN=$(( "${#DEPLOY_SIDE_STACK[@]}" - 1 ))

		DEPLOY_SIDE_STACK_FINAL=()

		for i in `seq 0 "${DEPLOY_SIDE_STACK_LEN}"`; do
			SIDE_STACK_DIR="${BASEDIR}"/../"${DEPLOY_SIDE_STACK[$i]}"
			if [ "${ENVIRONMENT}" == "local" ]; then
				if [ ! -f "${SIDE_STACK_DIR}"/"${ENVIRONMENT}"/.env ]; then
					echo "[GPD][DEPLOY][WARNING] side stack: ${DEPLOY_SIDE_STACK[$i]} defined but not deployed"
				else
					echo "[GPD][DEPLOY][INFO] include side stack: ${DEPLOY_SIDE_STACK[$i]}"
					DEPLOY_SIDE_STACK_FINAL+=("${DEPLOY_SIDE_STACK[$i]}")
				fi
			else
				if ! $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'test -f '"${SIDE_STACK_DIR}"'/'"${ENVIRONMENT}"'/.env'); then
					echo "[GPD][DEPLOY][WARNING] side stack: ${DEPLOY_SIDE_STACK[$i]} defined but not deployed"
				else
					echo "[GPD][DEPLOY][INFO] include side stack: ${DEPLOY_SIDE_STACK[$i]}"
					DEPLOY_SIDE_STACK_FINAL+=("${DEPLOY_SIDE_STACK[$i]}")
				fi
			fi
		done

		DEPLOY_SIDE_STACK_FINAL_LEN=$(( "${#DEPLOY_SIDE_STACK_FINAL[@]}" - 1 ))
	fi
}

function deploy_check_initial()
{
	if [ "${ENVIRONMENT}" == "local" ] && [ ! "${DEPLOY_TYPE}" == "full" ] && [ ! -d "${BASEDIR}"/"${ENVIRONMENT}"/data/acme ]; then
		echo "[GPD][DEPLOY][ERROR] no acme data directory found please use deploy-type full for initial deployment"
		exit 1
	fi
}

function deploy_check_running()
{
	if [ "${DEPLOY_FORCE}" == "true" ]; then
		echo "[GPD][DEPLOY][WARNING] ignore check running of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]}"
		return 0
	elif [ "${ENVIRONMENT}" == "local" ] && [ ! $(docker compose --env-file "${DEPLOY_STACK_ENV_FILE}" ps --services --status running "${DEPLOY_SERVICE[@]}" | wc -l) -eq "${DEPLOY_SERVICE_LEN}" ]; then
		echo "[GPD][DEPLOY][ERROR] not all services are running, preventing deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]}"
		return 1
	elif [ "${ENVIRONMENT}" != "local" ] && [ ! $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_STACK_ENV_FILE}"' ps --services --status running '"${DEPLOY_SERVICE_REMOTE}"' | wc -l') -eq "${DEPLOY_SERVICE_LEN}" ]; then
		echo "[GPD][DEPLOY][ERROR] not all services are running, preventing deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]}"
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

	if [ "${ENVIRONMENT}" == "local" ] && ! $(docker login -u "${CI_REGISTRY_USER}" -p "${CI_REGISTRY_PASSWORD}" "${CI_REGISTRY}" &>/dev/null); then
		echo "[GPD][DEPLOY][ERROR] login to registry failed"
		return 1
	elif [ "${ENVIRONMENT}" != "local" ] && ! gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker login -u '"${CI_REGISTRY_USER}"' -p '"${CI_REGISTRY_PASSWORD}"' '"${CI_REGISTRY}"' &>/dev/null'; then
		echo "[GPD][DEPLOY][ERROR] login to registry failed"
		return 1
	else
		echo "[GPD][DEPLOY] login to registry successful"
		return 0
	fi

}

function deploy_pull_images()
{
	if [ "${ENVIRONMENT}" == "local" ] && ! $(docker compose --env-file "${DEPLOY_STACK_ENV_FILE}" pull -q "${DEPLOY_SERVICE[@]}" &>/dev/null); then
		echo "[GPD][DEPLOY][ERROR] pulling images failed"
		return 1
	elif [ "${ENVIRONMENT}" != "local" ] && ! $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_STACK_ENV_FILE}"' pull -q '"${DEPLOY_SERVICE_REMOTE}"' &>/dev/null'); then
		echo "[GPD][DEPLOY][ERROR] pulling images failed"
		return 1
	else
		echo "[GPD][DEPLOY] pulling images successful"
		return 0
	fi
}

function deploy_dry_run()
{
	MAX_RETRIES=5
	RETRY_COUNT=0

	while [ "${RETRY_COUNT}" -lt "${MAX_RETRIES}" ]; do
		if [ "${ENVIRONMENT}" == "local" ]; then
			docker compose --env-file "${DEPLOY_STACK_ENV_FILE}" up --detach --dry-run --force-recreate --no-color "${DEPLOY_SERVICE[@]}" &>/dev/null && break
		else
			gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_STACK_ENV_FILE}"' up --detach --dry-run --force-recreate --no-color '"${DEPLOY_SERVICE_REMOTE}"' &>/dev/null' && break
		fi
		RETRY_COUNT=$((RETRY_COUNT+1))
		sleep 1
		echo "[GPD][DEPLOY][WARNING] docker compose --dry-run try ${RETRY_COUNT} failed, it usualy succeeds within 5 retries"
	done

	if [ "${DEPLOY_FORCE}" == "true" ]; then
		echo "[GPD][DEPLOY][WARNING] ignore dry run of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]}"
		return 0
	elif [ "${RETRY_COUNT}" -eq "${MAX_RETRIES}" ]; then
		echo "[GPD][DEPLOY][ERROR] dry run failed after ${MAX_RETRIES} retries"
		return 1
	else
		echo "[GPD][DEPLOY] dry run successful, continuing deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]}"
		return 0
	fi
}

function deploy_on_target()
{
	if [ "${ENVIRONMENT}" == "local" ] && ! $(docker compose --env-file "${DEPLOY_STACK_ENV_FILE}" up --detach --force-recreate --no-color "${DEPLOY_SERVICE[@]}" &>/dev/null); then
		echo "[GPD][DEPLOY][ERROR] deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]} failed"
		return 1
	elif [ "${ENVIRONMENT}" != "local" ] && [ $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_STACK_ENV_FILE}"' up --detach --force-recreate --no-color '"${DEPLOY_SERVICE_REMOTE}"' &>/dev/null') ]; then
		echo "[GPD][DEPLOY][ERROR] deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]} failed"
		return 1
	else
		echo "[GPD][DEPLOY] deployment of ${DEPLOY_TYPE}: ${DEPLOY_SERVICE[@]} successful"
		return 0
	fi
}

function deploy_logout_from_registry()
{
	if [ -z "${CI_REGISTRY}" ]; then
		echo "[GPD][DEPLOY][ERROR] no registry set, set CI_REGISTRY variable"
		exit 1
	fi

	if [ "${ENVIRONMENT}" == "local" ] && ! $(docker logout "${CI_REGISTRY}" &>/dev/null); then
		echo "[GPD][DEPLOY][ERROR] logout from registry failed"
		return 1
	elif [ "${ENVIRONMENT}" != "local" ] && ! gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker logout '"${CI_REGISTRY}"' &>/dev/null'; then
		echo "[GPD][DEPLOY][ERROR] logout from registry failed"
		return 1
	else
		echo "[GPD][DEPLOY] logout from registry successful"
		return 0
	fi

}

function deploy_check_main()
{
	read -r DEPLOY_MAIN_STACK < "${SCRIPT_DIR}"/../docker/variables/main
	DEPLOY_MAIN_STACK_ENV_FILE="${BASEDIR}"/../"${DEPLOY_MAIN_STACK}"/"${ENVIRONMENT}"/.env

	if [ "${ENVIRONMENT}" == "local" ]; then
		if [ ! -f "${DEPLOY_MAIN_STACK_ENV_FILE}" ]; then
			echo "[GPD][DEPLOY][ERROR] main stack: ${DEPLOY_MAIN_STACK} not deployed"
			return 1
		fi

		if [ ! $(docker compose --env-file "${DEPLOY_MAIN_STACK_ENV_FILE}" ps -a -q --status=running | wc -l) -eq $(docker compose --env-file "${DEPLOY_MAIN_STACK_ENV_FILE}" config --services | wc -l) ]; then
			echo "[GPD][DEPLOY][ERROR] not all services of main stack: ${DEPLOY_MAIN_STACK} are running"
			return 1
		else
			echo "[GPD][DEPLOY][INFO] all services of main stack: ${DEPLOY_MAIN_STACK} are running, continuing deployment"
		fi
		return 0
	else
		if ! $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'test -f '"${DEPLOY_MAIN_STACK_ENV_FILE}"''); then
			echo "[GPD][DEPLOY][ERROR] main stack: ${DEPLOY_MAIN_STACK} not deployed"
			return 1
		fi

		if [ ! $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_MAIN_STACK_ENV_FILE}"' ps -a -q --status=running | wc -l') -eq $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_MAIN_STACK_ENV_FILE}"' config --services | wc -l') ]; then
			echo "[GPD][DEPLOY][ERROR] not all services of main stack: ${DEPLOY_MAIN_STACK} are running"
			return 1
		else
			echo "[GPD][DEPLOY][INFO] all services of main stack: ${DEPLOY_MAIN_STACK} are running, continuing deployment"
		fi
		return 0
	fi
}

function deploy_side_down()
{
	for i in `seq 0 "${DEPLOY_SIDE_STACK_FINAL_LEN}"`; do
		DEPLOY_SIDE_STACK_ENV_FILE="${BASEDIR}"/../"${DEPLOY_SIDE_STACK_FINAL[$i]}"/"${ENVIRONMENT}"/.env
		if [ "${ENVIRONMENT}" == "local" ]; then
			if [ $(docker compose --env-file "${DEPLOY_SIDE_STACK_ENV_FILE}" ps -a -q --status=running | wc -l) -eq 0 ]; then
				echo "[GPD][DEPLOY] side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]} already stopped"
			else
				echo "[GPD][DEPLOY] stop side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]}"
				docker compose --env-file "${DEPLOY_SIDE_STACK_ENV_FILE}" down &>/dev/null
			fi
		else
			if [ $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_SIDE_STACK_ENV_FILE}"' ps -a -q --status=running | wc -l') -eq 0 ]; then
				echo "[GPD][DEPLOY] side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]} already stopped"
			else
				echo "[GPD][DEPLOY] stop side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]}"
				gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_SIDE_STACK_ENV_FILE}"' down &>/dev/null'
			fi
		fi
	done
}

function deploy_side_up()
{
	for i in `seq 0 "${DEPLOY_SIDE_STACK_FINAL_LEN}"`; do
		DEPLOY_SIDE_STACK_ENV_FILE="${BASEDIR}"/../"${DEPLOY_SIDE_STACK_FINAL[$i]}"/"${ENVIRONMENT}"/.env
		if [ "${ENVIRONMENT}" == "local" ]; then
			if ! $(docker compose --env-file "${DEPLOY_SIDE_STACK_ENV_FILE}" up -d &>/dev/null); then
				echo "[GPD][DEPLOY][ERROR] deploy side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]} failed"
				return 1
			else
				echo "[GPD][DEPLOY] deployment of side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]} successful"
			fi
		else
			if ! $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_SIDE_STACK_ENV_FILE}"' up -d &>/dev/null'); then
				echo "[GPD][DEPLOY][ERROR] deploy side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]} failed"
				return 1
			else
				echo "[GPD][DEPLOY] deployment of side stack: ${DEPLOY_SIDE_STACK_FINAL[$i]} successful"
			fi
		fi
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

	if [ -n "${DEPLOY_SIDE_STACK_FINAL_LEN}" ] && [ "${DEPLOY_SIDE_STACK_FINAL_LEN}" -ge 0 ]; then
		deploy_side_down
	else
		if [ ! -f "${SCRIPT_DIR}"/../docker/variables/main ]; then
			echo "[GPD][DEPLOY][INFO] not stopping any side stacks"
		fi
	fi

	if ! deploy_on_target; then
		exit 1
	fi

	if [ -n "${DEPLOY_SIDE_STACK_FINAL_LEN}" ] && [ "${DEPLOY_SIDE_STACK_FINAL_LEN}" -ge 0 ]; then
		if ! deploy_side_up; then
			exit 1
		fi
	else
		if [ ! -f "${SCRIPT_DIR}"/../docker/variables/main ]; then
			echo "[GPD][DEPLOY][INFO] not deploying any side stacks"
		fi
	fi
}
