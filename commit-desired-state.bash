#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

check_command regctl
check_command skopeo
echo ; echo "🎯🎯🎯 Publish pseudo-app and others 🎯🎯🎯" ; echo

echo "Push the desired state"
# publish the desired state
OCI_REF=${REGISTRY}/${NAMESPACE}/${PUBLIC_KEY_NAME}:latest
PUBLIC_KEY_DIGEST=$(regctl manifest get --format=raw-body ${OCI_REF} | jq -r '.layers[] | select(.mediaType=="'${PUBLIC_KEY_TYPE}'") | .digest')
OCI_REF=${REGISTRY}/${NAMESPACE}/${APP_NAME}:latest
APP_BLOB_DIGEST=$(regctl manifest get --format=raw-body ${OCI_REF} | jq -r '.layers[] | select(.mediaType=="'${APP_PACKAGE_TYPE}'") | .digest')
export SCHEME
export REGISTRY
export APP_NAME
export PUBLIC_KEY_NAME
export APP_BLOB_DIGEST
export PUBLIC_KEY_DIGEST
envsubst '${SCHEME},${REGISTRY},${APP_NAME},${APP_BLOB_DIGEST},${PUBLIC_KEY_NAME},${PUBLIC_KEY_DIGEST}' < docker-compose-desired-state.yaml.in > docker-compose-desired-state.yaml

OCI_REF=${REGISTRY}/${DEPLOYMENT_NAME}:desired
if regctl manifest head ${OCI_REF} &>/dev/null ; then
    LATEST_DESIRED_STATE_DIGEST=$(regctl manifest head ${OCI_REF})
else
    LATEST_DESIRED_STATE_DIGEST="MISSING_DEPLOYMENT"
fi

# push the desired state with a temporary tag to confirm update
OCI_REF=${REGISTRY}/${DEPLOYMENT_NAME}:tmp
regctl artifact put \
    --artifact-type ${DEPLOY_ARTIFACT_TYPE} \
    --file-media-type ${DESIRED_STATE_TYPE} \
    --file docker-compose-desired-state.yaml \
    ${OCI_REF}
DESIRED_STATE_DIGEST=$(regctl manifest head ${OCI_REF})

if [[ ${LATEST_DESIRED_STATE_DIGEST} == ${DESIRED_STATE_DIGEST} ]] ; then
    echo "No changes in the desired state, nothing to do" ; echo
else
    # push the desired state with a timestamp as version
    OCI_REF_TMP=${OCI_REF}
    OCI_REF=${REGISTRY}/${DEPLOYMENT_NAME}:$(date "+%Y%m%d%H%M%S")
    skopeo copy docker://${OCI_REF_TMP} docker://${OCI_REF}

    # push the same to the desired tag (cheap push, only tagging)
    OCI_REF=${REGISTRY}/${DEPLOYMENT_NAME}:desired
    skopeo copy docker://${OCI_REF_TMP} docker://${OCI_REF}
fi

# inform about result
echo "Margo desired-state specification can be pulled from"
echo "        ${REGISTRY}/${DEPLOYMENT_NAME}:desired"

BLOB_DIGEST=$(regctl manifest get --format=raw-body ${REGISTRY}/${DEPLOYMENT_NAME}:desired | jq -r '.layers[] | select(.mediaType=="'${DESIRED_STATE_TYPE}'") | .digest')
echo "Direct download (wget or get) of the desired-state YAML specification possible from"
echo "    ${SCHEME}://${REGISTRY}/v2/${DEPLOYMENT_NAME}/blobs/${BLOB_DIGEST}"
echo "    OAuthv2 token might be needed for it to work"

echo "🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯"

