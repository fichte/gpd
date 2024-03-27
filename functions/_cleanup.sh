function cleanup()
{
	if [[ -d "${STACK_FINAL_CONFIG_DIR}" ]]; then
		rm -rf "${STACK_FINAL_CONFIG_DIR}"
		echo "[GPD][CLEAN] cleanup successful"
	fi
}
