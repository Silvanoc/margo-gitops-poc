#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
LOG="prepare-app.log"
source "${THIS_DIR}/common.source"

check_command docker

cleanup() {
    set +e
    docker rmi ${APP_NAME}-web:latest &> ${LOG}
    rm -f "${APP_NAME}/${APP_NAME}-web.tar" "${APP_NAME}/${APP_NAME}-redis.tar"
    gpgconf --kill gpg-agent
    rm -r $GNUPGHOME
    unset $GNUPGHOME
}

trap cleanup EXIT

echo ; echo "📦📦📦 Create docker-compose app and package 📦📦📦"
echo ; echo "📦 Create a pseudo docker-compose app 📦"
echo "It will only contain a docker-compose file and two container image archives."
echo

export GNUPGHOME="$(mktemp -d ${TMPDIR}/gpgtemp.XXXXXXXXXX)"
gpg-agent --daemon &>> ${LOG}
KEY_ID=$(gpg --import margo-poc.private.pgp 2>&1 | grep '^gpg: key .*: public key .* imported$' | sed 's/^gpg: key \(.*\): .*/\1/')
rm -f "${APP_NAME}/${PUBLIC_KEY}"
gpg --output "${APP_NAME}/${PUBLIC_KEY}" --armor --export ${KEY_ID} &>> ${LOG}

(
    cd "${APP_NAME}"
    echo "Creating container image archive '${APP_NAME}-web'"
    docker build --tag ${APP_NAME}-web:latest . &>> ${LOG}
    docker save ${APP_NAME}-web:latest > ${APP_NAME}-web.tar

    echo "Creating container image archive '${APP_NAME}-redis.tar'"
    docker pull redis:alpine &>> ${LOG}
    docker save redis:alpine > ${APP_NAME}-redis.tar

    echo "Creating '${APP_NAME}.app'"
    tar -czf "${APP_NAME}.app" docker-compose.yaml ${APP_NAME}-web.tar ${APP_NAME}-redis.tar
    rm -f ${APP_NAME}-web.tar ${APP_NAME}-redis.tar

    echo ; echo "Content of the pseudo-app:"
    tar -tzf "${APP_NAME}.app"

    echo ; echo "Create app signature"
    rm -f "${APP_NAME}.app.sig"
    gpg --output "${APP_NAME}.app.sig" --detach-sign "${APP_NAME}.app"
    gpg --verify "${APP_NAME}.app.sig" "${APP_NAME}.app" &>> ${LOG}

    echo ; echo "📦 Create a pseudo-package to be pushed 📦"
    echo "It will contain the app and the signature" ; echo
    echo "Content of the pseudo-package:"
    tar -czf "${APP_NAME}.tar.gz" "${APP_NAME}.app" "${APP_NAME}.app.sig"
    tar -tzf "${APP_NAME}.tar.gz"
)

echo ; echo "📦📦📦📦📦📦📦📦📦📦📦📦📦📦📦📦📦📦📦" ; echo

