#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

check_command docker

cleanup() {
    set +e
    docker rmi ${APP_NAME}-web:latest
    rm "${APP_NAME}/${APP_NAME}-web.tar" "${APP_NAME}/${APP_NAME}-redis.tar"
    gpgconf --kill gpg-agent
    rm -r $GNUPGHOME
    unset $GNUPGHOME
}

trap cleanup EXIT

export GNUPGHOME="$(mktemp -d ${TMPDIR}/gpgtemp.XXXXXXXXXX)"
gpg-agent --daemon
KEY_ID=$(gpg --import margo-poc.private.pgp 2>&1 | grep '^gpg: key .*: public key .* imported$' | sed 's/^gpg: key \(.*\): .*/\1/')
gpg --output "${APP_NAME}/margo-poc.public.pgp" --armor --export ${KEY_ID}

(
    cd "${APP_NAME}"
    docker compose -f poc-compose.yaml build
    docker save ${APP_NAME}-web:latest > ${APP_NAME}-web.tar
    docker save redis:alpine > ${APP_NAME}-redis.tar
    tar -czf "${APP_NAME}.tgz" poc-compose.yaml ${APP_NAME}-web.tar ${APP_NAME}-redis.tar

    gpg --output "${APP_NAME}.tgz.sig" --detach-sign "${APP_NAME}.tgz"
    gpg --verify "${APP_NAME}.tgz.sig" "${APP_NAME}.tgz"
)

