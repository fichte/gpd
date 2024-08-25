function copy_config_files()
{
        while IFS= read -r LINE; do
        if [[ "${LINE}" == "${DEPLOY_TYPE}"=* ]]; then
                DEPLOY_SERVICES="${LINE#*=}"
                IFS=' ' read -r -a DEPLOY_SERVICE <<< "${DEPLOY_SERVICES}"
        fi
        done < "${SCRIPT_DIR}"/../docker/variables/deployments

	## copy asset files for selected deployment
	pushd "${SCRIPT_DIR}"/../docker/template/asset &>/dev/null
	for t in "${DEPLOY_SERVICE[@]}"; do
		ASSET_FILES_TEMPLATES=("${t}"_*_template)
		ASSET_FILES_TEMPLATES_LEN=$(( "${#ASSET_FILES_TEMPLATES[@]}" - 1 ))

		for u in `seq 0 "${ASSET_FILES_TEMPLATES_LEN}"`; do
			FINAL_CONFIG_FILE=$(echo "${ASSET_FILES_TEMPLATES[$u]}" | sed -e 's/_template//g')
			cp "${SCRIPT_DIR}"/../docker/template/asset/"${ASSET_FILES_TEMPLATES[$u]}" "${STACK_FINAL_CONFIG_DIR}"/asset/"${FINAL_CONFIG_FILE}"
		done
	done
	popd &>/dev/null

	## initialize array of all final asset files
	pushd "${STACK_FINAL_CONFIG_DIR}"/asset &>/dev/null
	ASSET_FILES=(*)
	popd &>/dev/null

	## copy compose files for selected deployment
	pushd "${SCRIPT_DIR}"/../docker/template/compose &>/dev/null
	for t in "${DEPLOY_SERVICE[@]}"; do
		FINAL_CONFIG_FILE=$(echo "${t}".yml_template | sed -e 's/_template//g')
		cp "${SCRIPT_DIR}"/../docker/template/compose/"${t}".yml_template "${STACK_FINAL_CONFIG_DIR}"/compose/"${FINAL_CONFIG_FILE}"
	done

	## create stack.yml
	echo "include:" >"${STACK_FINAL_CONFIG_DIR}"/compose/stack.yml

	for t in "${DEPLOY_SERVICE[@]}"; do
		awk -v item="${t}" '
		$0 ~ "- path: "item".yml" {found=1}
		found && $0 ~ "- path:" && $0 !~ item".yml" {found=0}
		found {print}
		' "${SCRIPT_DIR}"/../docker/template/compose/stack.yml_template >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack.yml
	done

	echo "" >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack.yml

	awk '/^networks:/,/^ *$/' "${SCRIPT_DIR}"/../docker/template/compose/stack.yml_template >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack.yml

	## create stack-common.yml
	awk '/^services:/ {exit} {print}' "${SCRIPT_DIR}"/../docker/template/compose/stack-common.yml_template >"${STACK_FINAL_CONFIG_DIR}"/compose/stack-common.yml

	echo "services:" >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack-common.yml

	for t in "${DEPLOY_SERVICE[@]}"; do
		awk -v service="${t}" '
		BEGIN {found=0}
		$1 == service ":" {found=1}
		found && NF == 0 {found=0}
		found {print}
		' "${SCRIPT_DIR}"/../docker/template/compose/stack-common.yml_template >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack-common.yml
		echo "" >>"${STACK_FINAL_CONFIG_DIR}"/compose/stack-common.yml
	done
	popd &>/dev/null

	## initialize array of all final compose files
	pushd "${STACK_FINAL_CONFIG_DIR}"/compose &>/dev/null
	COMPOSE_FILES=(*)
	popd &>/dev/null

	## copy config files for selected deployment
	pushd "${SCRIPT_DIR}"/../docker/template/config &>/dev/null
	for t in "${DEPLOY_SERVICE[@]}"; do
		CONFIG_FILES_TEMPLATES=("${t}"_*_template)
		CONFIG_FILES_TEMPLATES_LEN=$(( "${#CONFIG_FILES_TEMPLATES[@]}" - 1 ))

		for u in `seq 0 "${CONFIG_FILES_TEMPLATES_LEN}"`; do
			FINAL_CONFIG_FILE=$(echo "${CONFIG_FILES_TEMPLATES[$u]}" | sed -e 's/_template//g')
			cp "${SCRIPT_DIR}"/../docker/template/config/"${CONFIG_FILES_TEMPLATES[$u]}" "${STACK_FINAL_CONFIG_DIR}"/config/"${FINAL_CONFIG_FILE}"
		done
	done
	popd &>/dev/null

	## initialize array of all final config files
	pushd "${STACK_FINAL_CONFIG_DIR}"/config &>/dev/null
	CONFIG_FILES=(*)
	popd &>/dev/null
}
