function valid_environments()
{
	VALID_ENVIRONMENTS=()

	while IFS= read -r LINE; do
		VALID_ENVIRONMENTS+=("${LINE}")
	done < "${SCRIPT_DIR}/../docker/variables/environments"
}
