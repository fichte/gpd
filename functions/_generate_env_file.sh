function generate_env_file()
{
	sort -o "${STACK_FINAL_CONFIG_DIR}"/compose/stack.env "${STACK_FINAL_CONFIG_DIR}"/compose/stack.env
	STACK_SHA=$(find "${STACK_FINAL_CONFIG_DIR}"/compose "${STACK_FINAL_CONFIG_DIR}"/config -type f | grep -v 'passwd' | perl -lne 'print if -T' | sort | xargs sha256sum | awk '{ print $1 }' | sha256sum | awk '{ print $1 }')

	cat <<EOF >"${STACK_FINAL_CONFIG_DIR}"/.env
COMPOSE_ENV=${ENVIRONMENT}
COMPOSE_PROJECT_NAME=${STACK_NAME}
COMPOSE_FILE=${STACK_COMPOSE_PATH}/stack-common.yml:${STACK_COMPOSE_PATH}/stack.yml
COMPOSE_STACK_SHA=${STACK_SHA}
COMPOSE_COMMIT_SHA=${CI_COMMIT_SHORT_SHA}
EOF
	echo "[GPD][GENERATE] deployment checksum: ${STACK_SHA}"
}
