function remove_unused_images()
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

	gpd init

	DEPLOY_STACK_ENV_FILE="${BASEDIR}"/"${ENVIRONMENT}"/.env

	if [[ "${ENVIRONMENT}" == local* ]] && [ $(docker image ls -q -f "dangling=true" | wc -l) -gt 0 ]; then
			echo "[GPD][CLEAN] cleaning dangling images"
			if ! docker image rm $(docker image ls -q -f "dangling=true") &>/dev/null; then
				echo "[GPD][CLEAN][ERROR] cleaning dangling images failed"
			else
				echo "[GPD][CLEAN] cleaning dangling images successful"
			fi
	elif [[ "${ENVIRONMENT}" != local* ]] && [ $(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker image ls -q -f "dangling=true" | wc -l') -gt 0 ]; then
			if ! gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker image rm $(docker image ls -q -f "dangling=true") &>/dev/null'; then
				echo "[GPD][CLEAN][ERROR] cleaning dangling images failed"
			else
				echo "[GPD][CLEAN] cleaning dangling images successful"
			fi
	else
			echo "[GPD][CLEAN] no dangling images"
	fi

	if [[ "${ENVIRONMENT}" == local* ]]; then
		OUTPUT_COMPOSE=$(docker compose --env-file "${DEPLOY_STACK_ENV_FILE}" images | sed 1d)
	else
		OUTPUT_COMPOSE=$(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_STACK_ENV_FILE}"' images | sed 1d')
	fi

	IMAGE_COMPOSE=()
	VERSION_COMPOSE=()

	while IFS= read -r LINE; do
		VALUE_IMAGE=$(echo "$LINE" | awk '{print $2}')
		VALUE_VERSION=$(echo "$LINE" | awk '{print $3}')

		IMAGE_COMPOSE+=("${VALUE_IMAGE}")
		VERSION_COMPOSE+=("${VALUE_VERSION}")
	done <<< "$OUTPUT_COMPOSE"

	IMAGE_COMPOSE_LEN=$(( "${#IMAGE_COMPOSE[@]}" - 1 ))
	VERSION_COMPOSE_LEN=$(( "${#VERSION_COMPOSE[@]}" - 1 ))

	IMAGE_COMPOSE_DELETE=()

	for i in `seq 0 "${IMAGE_COMPOSE_LEN}"`; do
		echo "[GPD][INFO] keeping ${IMAGE_COMPOSE[$i]}:${VERSION_COMPOSE[$i]}"
		if [[ "${ENVIRONMENT}" == local* ]]; then
			IMAGE_LS_OUTPUT_COMPOSE=($(docker image ls --format '{{.Repository}}:{{.Tag}}' ${IMAGE_COMPOSE[$i]} | sed '/'"${VERSION_COMPOSE[$i]}"'/d'))
		else
			IMAGE_LS_OUTPUT_COMPOSE=($(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker image ls --format '{{.Repository}}:{{.Tag}}' '"${IMAGE_COMPOSE[$i]}"' | sed '/"${VERSION_COMPOSE[$i]}"/d''))
		fi
		IMAGE_DELETE_COMPOSE+=("${IMAGE_LS_OUTPUT_COMPOSE[@]}")
	done

	IMAGE_DELETE_COMPOSE=($(echo "${IMAGE_DELETE_COMPOSE[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

	for delete in "${IMAGE_DELETE_COMPOSE[@]}"; do
		echo "[GPD][CLEAN] removing unused image ${delete}"
		if [[ "${ENVIRONMENT}" == local* ]]; then
			docker image rm "${delete}" &>/dev/null
		else
			gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker image rm '"${delete}"' &>/dev/null'
		fi
	done

	if [ -z "${CI_REGISTRY}" ] || [ "$CI_REGISTRY" == "null" ] ; then
		echo "[GPD][CLEAN] no custom built images"
		exit 0
	fi

	if [[ "${ENVIRONMENT}" == local* ]]; then
		OUTPUT_CLI_KEEP_VERSION=$(docker compose --env-file "${DEPLOY_STACK_ENV_FILE}" images | grep "${CI_REGISTRY}/${CI_PROJECT_PATH}/" | awk '{ print $3 }' | head -1)
		OUTPUT_CLI=$(docker images | grep "${CI_REGISTRY}/${CI_PROJECT_PATH}/" | sed '/'"${OUTPUT_CLI_KEEP_VERSION}"'/d')
	else
		OUTPUT_CLI_KEEP_VERSION=$(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker compose --env-file '"${DEPLOY_STACK_ENV_FILE}"' images | grep "'"${CI_REGISTRY}"'/'"${CI_PROJECT_PATH}"'/" | awk '"'"'{ print $3 }'"'"' | head -1')
		OUTPUT_CLI=$(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker images | grep "'"${CI_REGISTRY}"'/'"${CI_PROJECT_PATH}"'/" | sed '/"${OUTPUT_CLI_KEEP_VERSION}"/d'')
	fi

	IMAGE_CLI=()
	VERSION_CLI=()

	while IFS= read -r LINE; do
		VALUE_IMAGE=$(echo "$LINE" | awk '{print $1}')
		VALUE_VERSION=$(echo "$LINE" | awk '{print $2}')

		IMAGE_CLI+=("${VALUE_IMAGE}")
		VERSION_CLI+=("${VALUE_VERSION}")
	done <<< "$OUTPUT_CLI"

	IMAGE_CLI_LEN=$(( "${#IMAGE_CLI[@]}" - 1 ))
	VERSION_CLI_LEN=$(( "${#VERSION_CLI[@]}" - 1 ))

	IMAGE_CLI_DELETE=()

	for i in `seq 0 "${IMAGE_CLI_LEN}"`; do
		if [[ "${ENVIRONMENT}" == local* ]]; then
			IMAGE_LS_OUTPUT_CLI=($(docker image ls --format '{{.Repository}}:{{.Tag}}' ${IMAGE_CLI[$i]}:"${VERSION_CLI[$i]}" ))
		else
			IMAGE_LS_OUTPUT_CLI=($(gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker image ls --format '{{.Repository}}:{{.Tag}}' '"${IMAGE_CLI[$i]}"':'"${VERSION_CLI[$i]}"''))
		fi
		IMAGE_DELETE_CLI+=("${IMAGE_LS_OUTPUT_CLI[@]}")
	done

	IMAGE_DELETE_CLI=($(echo "${IMAGE_DELETE_CLI[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

	for delete in "${IMAGE_DELETE_CLI[@]}"; do
		echo "[GPD][CLEAN] removing unused image ${delete}"
		if [[ "${ENVIRONMENT}" == local* ]]; then
			docker image rm "${delete}" &>/dev/null
		else
			gpd ssh "${!STACK_DEPLOY_USER}"@"${!STACK_DEPLOY_HOST}" 'docker image rm '"${delete}"' &>/dev/null'
		fi
	done
}
