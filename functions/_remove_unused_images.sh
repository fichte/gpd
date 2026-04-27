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

	if [[ "${ENVIRONMENT}" == local* ]]; then
		unset DOCKER_HOST
	fi

	## prune dangling images
	local DANGLING
	DANGLING=$(run_in_target docker image ls -q -f "dangling=true")
	if [ -n "${DANGLING}" ]; then
		echo "[GPD][CLEAN] cleaning dangling images"
		# shellcheck disable=SC2086
		if run_in_target docker image rm ${DANGLING} >/dev/null 2>&1; then
			echo "[GPD][CLEAN] cleaning dangling images successful"
		else
			echo "[GPD][CLEAN][ERROR] cleaning dangling images failed"
		fi
	else
		echo "[GPD][CLEAN] no dangling images"
	fi

	## list compose-managed images, skipping the table header
	local OUTPUT_COMPOSE
	OUTPUT_COMPOSE=$(compose_in_target "${DEPLOY_STACK_ENV_FILE}" images | tail -n +2)

	local IMAGE_COMPOSE=() VERSION_COMPOSE=() LINE
	while IFS= read -r LINE; do
		[ -z "${LINE}" ] && continue
		IMAGE_COMPOSE+=("$(awk '{print $2}' <<< "${LINE}")")
		VERSION_COMPOSE+=("$(awk '{print $3}' <<< "${LINE}")")
	done <<< "${OUTPUT_COMPOSE}"

	## for each compose-managed image, find other-tagged copies on the host
	## and queue them for removal
	local IMAGE_DELETE_COMPOSE=()
	local i OTHER_TAGS TAG
	for (( i=0; i<${#IMAGE_COMPOSE[@]}; i++ )); do
		echo "[GPD][INFO] keeping ${IMAGE_COMPOSE[$i]}:${VERSION_COMPOSE[$i]}"
		OTHER_TAGS=$(run_in_target docker image ls --format '{{.Repository}}:{{.Tag}}' "${IMAGE_COMPOSE[$i]}" | grep -vF ":${VERSION_COMPOSE[$i]}" || true)
		if [ -n "${OTHER_TAGS}" ]; then
			while IFS= read -r TAG; do
				[ -n "${TAG}" ] && IMAGE_DELETE_COMPOSE+=("${TAG}")
			done <<< "${OTHER_TAGS}"
		fi
	done

	## dedupe and remove
	if [ "${#IMAGE_DELETE_COMPOSE[@]}" -gt 0 ]; then
		local UNIQUE_DELETE
		UNIQUE_DELETE=$(printf '%s\n' "${IMAGE_DELETE_COMPOSE[@]}" | sort -u)
		while IFS= read -r TAG; do
			[ -z "${TAG}" ] && continue
			echo "[GPD][CLEAN] removing unused image ${TAG}"
			run_in_target docker image rm "${TAG}" >/dev/null 2>&1 || true
		done <<< "${UNIQUE_DELETE}"
	fi

	## custom-built CI image cleanup — only when a custom registry is configured
	if [ -z "${CI_REGISTRY}" ] || [ "${CI_REGISTRY}" == "null" ]; then
		echo "[GPD][CLEAN] no custom built images"
		return 0
	fi

	local KEEP_VERSION
	KEEP_VERSION=$(compose_in_target "${DEPLOY_STACK_ENV_FILE}" images | grep -F "${CI_REGISTRY}/${CI_PROJECT_PATH}/" | awk '{print $3}' | head -1 || true)

	if [ -z "${KEEP_VERSION}" ]; then
		echo "[GPD][CLEAN] no compose-managed image from ${CI_REGISTRY}/${CI_PROJECT_PATH}/"
		return 0
	fi

	local OLD_BUILDS
	OLD_BUILDS=$(run_in_target docker images --format '{{.Repository}}:{{.Tag}}' | grep -F "${CI_REGISTRY}/${CI_PROJECT_PATH}/" | grep -vF ":${KEEP_VERSION}" || true)

	if [ -n "${OLD_BUILDS}" ]; then
		while IFS= read -r TAG; do
			[ -z "${TAG}" ] && continue
			echo "[GPD][CLEAN] removing unused image ${TAG}"
			run_in_target docker image rm "${TAG}" >/dev/null 2>&1 || true
		done <<< "${OLD_BUILDS}"
	fi
}
