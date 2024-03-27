#!/usr/bin/env bash

FUNCTIONS_DIR=$(dirname "$(readlink -e "${0}")")/functions

for FUNCTIONS_PATH in "${FUNCTIONS_DIR}"/_*; do
	. "${FUNCTIONS_PATH}"
done
