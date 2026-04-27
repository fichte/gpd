#!/usr/bin/env bash

set -e -o pipefail
shopt -s nullglob

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
	echo "[GPD][ERROR] GPD requires Bash 4 or newer (running ${BASH_VERSION:-unknown})" >&2
	echo "[GPD][ERROR] On macOS install a recent Bash via: brew install bash" >&2
	exit 1
fi

# Portable symlink-resolving realpath. perl is a required dependency, so it is
# the universal fallback for systems without GNU readlink -e or BSD readlink -f.
gpd_realpath()
{
	if readlink -e -- / >/dev/null 2>&1; then
		readlink -e -- "${1}"
	elif readlink -f -- / >/dev/null 2>&1; then
		readlink -f -- "${1}"
	elif command -v realpath >/dev/null 2>&1; then
		realpath -- "${1}"
	else
		perl -MCwd -e 'print Cwd::realpath($ARGV[0])' -- "${1}"
	fi
}

SCRIPT_DIR=$(dirname "$(gpd_realpath "${0}")")
ENV_CONFIG_DIR="${SCRIPT_DIR}"/../docker/config
DEPLOY_FORCE="false"
UNUSED="false"
RETRIES="3"
source "${SCRIPT_DIR}"/functions/include.sh
valid_environments
valid_deployments

if ! [[ "${RETRIES}" =~ ^[1-9][0-9]*$ ]]; then
	echo "[GPD][ERROR] --retries must be a positive integer (got \"${RETRIES}\")"
	exit 1
fi

if [[ -z "${BASEDIR}" ]]; then
	echo "[GPD][ERROR] please provide a base directory"
	exit 1
fi

if [[ -z "${ENVIRONMENT}" ]] || ! array_contains "${ENVIRONMENT}" "${VALID_ENVIRONMENTS[@]}"; then
	echo "[GPD][ERROR] please provide an environment"
	echo "[GPD][ERROR] valid environments are \"${VALID_ENVIRONMENTS[*]}\""
	exit 1
fi

if [[ "${GENERATE}" == "true" || "${DEPLOY}" == "true" ]] && ! array_contains "${DEPLOY_TYPE}" "${VALID_DEPLOYMENTS[@]}"; then
	echo "[GPD][ERROR] please provide a deployment type"
	echo "[GPD][ERROR] valid deployments are \"${VALID_DEPLOYMENTS[*]}\""
	exit 1
fi

echo "[GPD][INFO] using environment \"${ENVIRONMENT}\""
variables_base
echo "[GPD][INFO] using ci variables file \"${STACK_ENVIRONMENT_VARIABLES}\""
echo "[GPD][INFO] using final config directory \"${STACK_FINAL_CONFIG_DIR}\""
echo "[GPD][INFO] using remote/local asset directory \"${STACK_ASSET_PATH}\""
echo "[GPD][INFO] using remote/local compose directory \"${STACK_COMPOSE_PATH}\""
echo "[GPD][INFO] using remote/local config directory \"${STACK_CONFIG_PATH}\""
echo "[GPD][INFO] using remote/local data directory \"${STACK_DATA_PATH}\""

if [[ "${CLEAN}" == "true" ]]; then
	cleanup
fi

if [[ "${GENERATE}" == "true" ]]; then
	generate
fi

if [[ "${PUSH}" == "true" ]]; then
	push
fi

if [[ "${DEPLOY}" == "true" ]]; then
	deploy
fi

if [[ "${UNUSED}" == "true" ]]; then
	remove_unused_images
fi
