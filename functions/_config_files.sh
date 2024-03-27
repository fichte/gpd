function copy_config_files()
{
	## initialize array of available compose files
	pushd "${SCRIPT_DIR}"/../docker/template/compose &>/dev/null
	COMPOSE_FILES_TEMPLATES=(*_template)
	COMPOSE_FILES_TEMPLATES_LEN=$(( "${#COMPOSE_FILES_TEMPLATES[@]}" - 1 ))
	popd &>/dev/null

	for t in `seq 0 "${COMPOSE_FILES_TEMPLATES_LEN}"`; do
		FINAL_CONFIG_FILE=$(echo "${COMPOSE_FILES_TEMPLATES[$t]}" | sed -e 's/_template//g')
		cp "${SCRIPT_DIR}"/../docker/template/compose/"${COMPOSE_FILES_TEMPLATES[$t]}" "${STACK_FINAL_CONFIG_DIR}"/compose/"${FINAL_CONFIG_FILE}"
	done

	## initialize array of all final config files
	pushd "${STACK_FINAL_CONFIG_DIR}"/compose &>/dev/null
	COMPOSE_FILES=(*)
	popd &>/dev/null

	## initialize array of available config files
	pushd "${SCRIPT_DIR}"/../docker/template/config &>/dev/null
	CONFIG_FILES_TEMPLATES=(*_template)
	CONFIG_FILES_TEMPLATES_LEN=$(( "${#CONFIG_FILES_TEMPLATES[@]}" - 1 ))
	popd &>/dev/null

	for t in `seq 0 "${CONFIG_FILES_TEMPLATES_LEN}"`; do
		FINAL_CONFIG_FILE=$(echo "${CONFIG_FILES_TEMPLATES[$t]}" | sed -e 's/_template//g')
		cp "${SCRIPT_DIR}"/../docker/template/config/"${CONFIG_FILES_TEMPLATES[$t]}" "${STACK_FINAL_CONFIG_DIR}"/config/"${FINAL_CONFIG_FILE}"
	done

	## initialize array of all final config files
	pushd "${STACK_FINAL_CONFIG_DIR}"/config &>/dev/null
	CONFIG_FILES=(*)
	popd &>/dev/null
}
