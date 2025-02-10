function gpd()
{
	if [[ "${ENVIRONMENT}" == local* ]]; then
		RSYNC_OPTIONS_LOCAL="-avqz"
	else
		STACK_DEPLOY_HOST="${ENVIRONMENT^^}"_STACK_DEPLOY_HOST
		STACK_DEPLOY_USER="${ENVIRONMENT^^}"_STACK_DEPLOY_USER
		STACK_DEPLOY_SSH_KEY="${ENVIRONMENT^^}"_STACK_DEPLOY_SSH_KEY
		STACK_DEPLOY_SSH_KNOWN_HOSTS="${ENVIRONMENT^^}"_STACK_DEPLOY_SSH_KNOWN_HOSTS
		RSYNC_OPTIONS_REMOTE="ssh -q -o UserKnownHostsFile=${!STACK_DEPLOY_SSH_KNOWN_HOSTS} -o StrictHostKeyChecking=yes -i ${!STACK_DEPLOY_SSH_KEY}"
		SSH_OPTIONS="-A -q -o UserKnownHostsFile=${!STACK_DEPLOY_SSH_KNOWN_HOSTS} -o StrictHostKeyChecking=yes -o ConnectTimeout=3 -i ${!STACK_DEPLOY_SSH_KEY}"
		SCP_OPTIONS="-r -q -o UserKnownHostsFile=${!STACK_DEPLOY_SSH_KNOWN_HOSTS} -o StrictHostKeyChecking=yes -i ${!STACK_DEPLOY_SSH_KEY}"
		chmod 600 "${!STACK_DEPLOY_SSH_KEY}"
	fi

	local MODE="${1}"

	function scp_ipv6()
	{
		if echo "${1}" | grep -q ":"; then
			echo "${1}" | sed -e 's/\(.*@\)\(.*\)/\1[\2]/'
		else
			echo "${1}"
		fi
	}

	function check_payload()
	{
		if [ "${1: -1}" == ";" ]; then
			echo "${1}"
		else
			echo "${1};"
		fi
	}

	if [ "${MODE}" == "init" ]; then
		return 0
	elif [ "${MODE}" == "ssh" ]; then
		shift 1
		local TARGET="${1}"
		local PAYLOAD=$(check_payload "${2}")
		CMD=(ssh ${SSH_OPTIONS} "${TARGET}" '{ '"${PAYLOAD}"' }')
		"${CMD[@]}"
	elif [ "${MODE}" == "scp" ]; then
		shift 1
		local SRC_FILE=${1}
		local DST=$(scp_ipv6 ${2})
		local DST_FILE=${3}
		CMD=(scp ${SCP_OPTIONS} "${SRC_FILE}" "${DST}":"${DST_FILE}")
		"${CMD[@]}"
	elif [ "${MODE}" == "rsync" ]; then
		shift 1
		local SRC_FILE=${1}
		local DST_FILE=${2}

		if [[ ! "${ENVIRONMENT}" == local* ]]; then
			local DST=$(scp_ipv6 ${!STACK_DEPLOY_HOST})
			CMD=(rsync -azqe "${RSYNC_OPTIONS_REMOTE}" "${SRC_FILE}" "${!STACK_DEPLOY_USER}"@"${DST}":"${DST_FILE}")
		else
			local DST="local"
			CMD=(rsync "${RSYNC_OPTIONS_LOCAL}" "${SRC_FILE}" "${DST_FILE}")
		fi

		if ! "${CMD[@]}" 2>/dev/null; then
			echo "[GPD][ERROR] transfer from local:${SRC_FILE} to ${DST}:${DST_FILE} failed"
			exit 1
		else
			echo "[GPD][PUSH] successfully transfered from local:${SRC_FILE} to ${DST}:${DST_FILE}"
		fi
	elif [ "${MODE}" == "diffenv" ]; then
		shift 1
		local SRC_FILE=${1}
		local DST_FILE=${2}

		if [[ ! "${ENVIRONMENT}" == local* ]]; then
			local DST=$(scp_ipv6 ${!STACK_DEPLOY_HOST})
			local TEMPFILE=$(mktemp)
			ssh ${SSH_OPTIONS} "${!STACK_DEPLOY_USER}"@"${DST}" 'cat '"${DST_FILE}"'/'"${ENVIRONMENT}"'/.env' >"${TEMPFILE}"
			CMD=(diff "${SRC_FILE}"/.env "${TEMPFILE}")
		else
			local DST="local"
			CMD=(diff "${SRC_FILE}"/.env "${DST_FILE}"/"${ENVIRONMENT}"/.env)
		fi

		if ! "${CMD[@]}" &>/dev/null; then
			rm -f "${TEMPFILE}"
			return 1
		else
			rm -f "${TEMPFILE}"
			return 0
		fi
	else
		echo "unknown mode"
		exit 1
	fi
}
