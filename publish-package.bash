#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

check_command regctl
echo ; echo "🚀🚀🚀 Publish pseudo-app and others 🚀🚀🚀" ; echo

# publish the public signing key
echo "Push the public signing key"
echo "  Inspired by provided example: https://specification.margo.org/margo-api-reference/workload-api/desired-state-api/desired-state/#example-standalone-device-application-deployment-specification"
OCI_REF=${REGISTRY}/silvanoc/${PUBLIC_KEY_NAME}:latest
(
    cd "${APP_NAME}"
    regctl artifact put \
        --artifact-type ${PUBLIC_KEY_TYPE} \
        --file-media-type ${PUBLIC_KEY_TYPE} \
        --file ${PUBLIC_KEY} \
        ${OCI_REF}
)
# inform about result
echo "PGP public key can be pulled from"
echo "        ${OCI_REF}"

echo ; echo "Push the package"
echo "It publishes the package and its content (unpackaged)"
OCI_REF=${REGISTRY}/${NAMESPACE}/${APP_NAME}:latest
# publish the package
(
    cd "${APP_NAME}"
    regctl artifact put \
        --artifact-type ${APP_PACKAGE_TYPE} \
        --file-media-type ${APP_PACKAGE_TYPE} \
        --file ${APP_NAME}.tar.gz \
        --file-media-type ${APP_ARCHIVE_TYPE} \
        --file ${APP_NAME}.app \
        --file-media-type ${APP_SIGNATURE_TYPE} \
        --file ${APP_NAME}.app.sig \
        ${OCI_REF}
)

# inform about result
echo "Margo package can be pulled from"
echo "        ${OCI_REF}"

echo ; echo "🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀🚀" ; echo

