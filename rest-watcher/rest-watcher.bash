#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/../common.source"

REG_URL="https://ghcr.io/v2"
TAG_URL="${REG_URL}/silvanoc/poc-deploy/manifests/desired"
BLOB_URL_PRFX="${REG_URL}/silvanoc/poc-deploy/blobs/"

check_command curl
check_command jq
check_command sed

BEARER_TOKEN=""

get_bearer_token() {
    AUTH_INFO=$(curl --silent --output /dev/null --write-out '%{header_json}' ${TAG_URL} | jq -r '."www-authenticate"[0]')
    REALM="$(echo "${AUTH_INFO}" | sed 's/.*realm="\([^"]*\).*/\1/')"
    SERVICE="$(echo "${AUTH_INFO}" | sed 's/.*service="\([^"]*\).*/\1/')"
    SCOPE="$(echo "${AUTH_INFO}" | sed 's/.*scope="\([^"]*\).*/\1/')"

    B64_CREDS="$(echo "${GH_CR_USER}:${GH_CR_TOKEN}" | base64)"
    BEARER_TOKEN="$(curl --silent \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic ${B64_CREDS}" \
        "${REALM}?service=${SERVICE}&scope=${SCOPE}" | jq -r '.token')"
}

HTTP_CODE=$(curl --output /dev/null --write-out '%{response_code}' ${TAG_URL} 2>/dev/null)

if [[ "${HTTP_CODE}" == 401 ]] ; then
    get_bearer_token
    HEADER=(-H "Authorization: Bearer ${BEARER_TOKEN}")
else
    HEADER=()
fi

DESIRED_STATE_DIGEST=$(
    curl --silent \
        "${HEADER[@]}" \
        -H "Accept: application/vnd.oci.image.manifest.list.v2+json" \
        -H "Accept: application/vnd.oci.image.manifest.v2+json" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        ${TAG_URL} \
    | jq -r '.layers[0].digest'
)

curl --location \
    "${HEADER[@]}" \
    ${BLOB_URL_PRFX}${DESIRED_STATE_DIGEST}
