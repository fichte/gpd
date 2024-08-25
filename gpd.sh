#!/usr/bin/env bash

set -e -o pipefail
shopt -s nullglob

SCRIPT_DIR=$(dirname "$(readlink -e "${0}")")
ENV_CONFIG_DIR="${SCRIPT_DIR}"/../docker/config
DEPLOY_FORCE="false"
UNUSED="false"
source "${SCRIPT_DIR}"/functions/include.sh
valid_environments
valid_deployments

if [[ -z "${BASEDIR}" ]]; then
	echo "[GPD][ERROR] please provide a base directory"
	exit 1
fi

if [[ -z "${ENVIRONMENT}" ]] || ! [[ "${VALID_ENVIRONMENTS[@]}" =~ "${ENVIRONMENT}" ]]; then
	echo "[GPD][ERROR] please provide an environment"
	echo "[GPD][ERROR] valid environments are \"${VALID_ENVIRONMENTS[@]}\""
	exit 1
elif [[ "${GENERATE}" == "true" ]] && ! [[ "${VALID_DEPLOYMENTS[@]}" =~ "${DEPLOY_TYPE}" ]]; then
	echo "[GPD][ERROR] please provide a deployment type"
	echo "[GPD][ERROR] valid deployments are \"${VALID_DEPLOYMENTS[@]}\""
elif [[ "${DEPLOY}" == "true" ]] && ! [[ "${VALID_DEPLOYMENTS[@]}" =~ "${DEPLOY_TYPE}" ]]; then
	echo "[GPD][ERROR] please provide a deployment type"
	echo "[GPD][ERROR] valid deployments are \"${VALID_DEPLOYMENTS[@]}\""
else
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
fi
