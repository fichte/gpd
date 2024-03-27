function valid_deployments()
{
	VALID_DEPLOYMENTS=()

	while IFS= read -r LINE; do
		DEPLOYMENT="${LINE%%=*}"
		DEPLOYMENT="${DEPLOYMENT##*( )}"
		DEPLOYMENT="${DEPLOYMENT%%*( )}"
		VALID_DEPLOYMENTS+=("${DEPLOYMENT}")
	done < "${SCRIPT_DIR}/../docker/variables/deployments"
}
