#!/bin/bash -e
set -o pipefail

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path to the script directory
BASEDIR=$(dirname "$SCRIPT")

# Package filename
PACKAGE_NAME="${1}"
PACKAGE_VERSION="${2}"
PACKAGE_FULL_NAME="${PACKAGE_NAME}-${PACKAGE_VERSION}"

CHART_PACKAGE="chart-${PACKAGE_FULL_NAME}.tar.gz"
BUNDLE_PACKAGE="bundle-${PACKAGE_FULL_NAME}.tar"

# # Shift positionals to remove the packages file name from script arguments
shift
shift
shift

printf "#### Connecting to Gravity Ops Center ...\n" | tee -a ${LOG_FILE}
gravity ops connect --insecure https://localhost:3009 admin Passw0rd123
printf "#### Pushing ${CHART_PACKAGE} to Gravity Ops Center ...\n" | tee -a ${LOG_FILE}
gravity app import --force --insecure --ops-url=https://localhost:3009 ${BASEDIR}/${CHART_PACKAGE}
printf "#### Executing ${BUNDLE_PACKAGE} installation ...\n" | tee -a ${LOG_FILE}
var_random=$RANDOM
gravity app install --name ${PACKAGE_NAME}-${var_random} --set global.localRegistry=leader.telekube.local:5000/ $@ ${BASEDIR}/${BUNDLE_PACKAGE}
printf "#### wait for job ${PACKAGE_NAME}-${var_random} ...\n" | tee -a ${LOG_FILE}
job_name=$(kubectl get jobs -n kube-system --sort-by=.metadata.creationTimestamp -o custom-columns=":metadata.name" | grep ${PACKAGE_NAME} | tail -n 1)
kubectl wait -n kube-system --for=condition=complete --timeout=20m job/${job_name}