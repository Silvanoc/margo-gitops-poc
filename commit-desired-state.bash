#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

check_command regctl

# publish the public signing key
(
    cd "${APP_NAME}"
    regctl artifact put \
        --artifact-type ${APP_ARTIFACT_TYPE}-signature \
        --file-media-type ${APP_SIGNATURE_TYPE} \
        --file ${APP_NAME}.tgz.sig \
        ${REGISTRY}/${PUBLIC_KEY}:latest
)


# publish the app
(
    cd "${APP_NAME}"
    regctl artifact put \
        --artifact-type ${APP_ARTIFACT_TYPE} \
        --file-media-type ${APP_ARCHIVE_TYPE} \
        --file ${APP_NAME}.tgz \
        ${REGISTRY}/${APP_NAME}:latest
)

# publish the desired state
APP_BLOB_DIGEST=$(regctl manifest get --format=raw-body ${REGISTRY}/${APP_NAME}:latest | jq -r '.layers[] | select(.mediaType=="'${APP_ARCHIVE_TYPE}'") | .digest')
SIG_BLOB_DIGEST=$(regctl manifest get --format=raw-body ${REGISTRY}/${PUBLIC_KEY}:latest | jq -r '.layers[] | select(.mediaType=="'${APP_SIGNATURE_TYPE}'") | .digest')
export SCHEME
export REGISTRY
export APP_NAME
export PUBLIC_KEY
export APP_BLOB_DIGEST
export SIG_BLOB_DIGEST
envsubst '${SCHEME},${REGISTRY},${APP_NAME},${APP_BLOB_DIGEST},${PUBLIC_KEY},${SIG_BLOB_DIGEST}' < docker-compose-desired-state.yaml.in > docker-compose-desired-state.yaml
regctl artifact put \
    --artifact-type ${DEPLOY_ARTIFACT_TYPE} \
    --file-media-type ${DESIRED_STATE_TYPE} \
    --file docker-compose-desired-state.yaml \
    ${REGISTRY}/${DEPLOYMENT_NAME}:desired

# inform about result
echo "Margo desired-state specification can be pulled from"
echo "        ${REGISTRY}/${DEPLOYMENT_NAME}:desired"
echo "    it can also be seen in the UI here"
echo "        ${SCHEME}://${REGISTRY}/image/${DEPLOYMENT_NAME}/tag/desired"

BLOB_DIGEST=$(regctl manifest get --format=raw-body ${REGISTRY}/${DEPLOYMENT_NAME}:desired | jq -r '.layers[] | select(.mediaType=="'${DESIRED_STATE_TYPE}'") | .digest')
echo "Direct download (wget or get) of the desired-state YAML specification possible from"
echo "    ${SCHEME}://${REGISTRY}/v2/${DEPLOYMENT_NAME}/blobs/${BLOB_DIGEST}"

