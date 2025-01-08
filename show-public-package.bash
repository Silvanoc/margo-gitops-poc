#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

check_command regctl

echo ; echo "🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍"

echo ; echo "🔍🔍🔍 Show signing public key 🔍🔍🔍" ; echo
OCI_REF="${REGISTRY}/silvanoc/${PUBLIC_KEY_NAME}:latest"
regctl manifest get --format=raw-body ${OCI_REF} | jq -r '.'

echo ; echo "🔍🔍🔍 Show published package 🔍🔍🔍" ; echo
OCI_REF="${REGISTRY}/${NAMESPACE}/${APP_NAME}:latest"
regctl manifest get --format=raw-body ${OCI_REF} | jq -r '.'

echo ; echo "🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍" ; echo

