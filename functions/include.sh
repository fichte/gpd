#!/usr/bin/env bash

FUNCTIONS_DIR=$(dirname "${BASH_SOURCE[0]}")

for FUNCTIONS_PATH in "${FUNCTIONS_DIR}"/_*; do
	. "${FUNCTIONS_PATH}"
done
