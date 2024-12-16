#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

fail() {
    echo "🚨 ERROR: $1"
    exit 1
}

check_command() {
    if command -v $1 >/dev/null ; then
        return 0
    else
        fail "Command '$1' is missing"
    fi
}

check_command regctl

regctl artifact put \
    --artifact-type ${ARTIFACT_TYPE} \
    --file-media-type ${DESIRED_STATE_TYPE} \
    --file docker-compose-desired-state.yaml \
    ${HOST}:${PORT}/${DEPLOYMENT_NAME}:desired

echo "Margo desired-state specification can be pulled from"
echo "        ${HOST}:${PORT}/${DEPLOYMENT_NAME}:desired"
echo "    it can also be seen in the UI here"
echo "        ${SCHEME}://${HOST}:${PORT}/image/${DEPLOYMENT_NAME}/tag/desired"

BLOB_DIGEST=$(regctl manifest get --format=raw-body ${HOST}:${PORT}/${DEPLOYMENT_NAME}:desired | jq -r '.layers[] | select(.mediaType=="'${DESIRED_STATE_TYPE}'") | .digest')
echo "Direct download (wget or get) of the desired-state YAML specification possible from"
echo "    ${SCHEME}://${HOST}:${PORT}/v2/${DEPLOYMENT_NAME}/blobs/${BLOB_DIGEST}"

