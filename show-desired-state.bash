#!/usr/bin/env bash

set -eu

THIS_SCRIPT="$(readlink -f "$0")"
THIS_DIR="$(dirname "${THIS_SCRIPT}")"
source "${THIS_DIR}/common.source"

check_command regctl

echo ; echo "🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍"

echo ; echo "🔍🔍🔍 Show desired state artifact 🔍🔍🔍" ; echo
OCI_REF=${REGISTRY}/${DEPLOYMENT_NAME}:desired
regctl manifest get --format=raw-body ${OCI_REF} | jq -r '.'

DESIRED_STATE_DIGEST=$(regctl manifest get --format=raw-body ${OCI_REF} | jq -r '.layers[0].digest')

echo ; echo "🔍🔍🔍 Show desired state 🔍🔍🔍" ; echo
regctl blob get ${OCI_REF} ${DESIRED_STATE_DIGEST}

echo ; echo "🔍🔍🔍 Show all desired state versions 🔍🔍🔍" ; echo
OCI_REF=${REGISTRY}/${DEPLOYMENT_NAME}
regctl tag ls ${OCI_REF} | sort

echo ; echo "🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍🔍" ; echo

