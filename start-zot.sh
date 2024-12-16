#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

CONT_NAME="margo-registry"
TMP_DIR=${PWD}/tmp/registry-storage

docker rm \
    -f \
    "${CONT_NAME}" &> /dev/null

# rm -rf $TMP_DIR
mkdir -p $TMP_DIR

docker run \
    -d \
    -p ${PORT}:5000 \
    --name "${CONT_NAME}" \
    -v ${TMP_DIR}:/var/lib/registry \
    ghcr.io/project-zot/zot-linux-$(uname -m):latest

echo "ZOT registry UI should be visible on ${SCHEME}://${HOST}:${PORT}"
