#!/bin/bash
set -o pipefail

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path to the script directory
BASEDIR=$(dirname "$SCRIPT")

# Package fullpath
PACKAGE=${1}
# Package filename
PACKAGE_FILENAME="${PACKAGE##*/}"
# Package name (without file extension)
PACKAGE_NAME="${PACKAGE_FILENAME%.tar.gz}"


# check if the APP is already listed in the gravity package list
# if exist then skip all load 
# if not load it.


LOG_DIR="/var/log"
INSTALL_LOG_FILE="${LOG_DIR}/gravity_package_install__${PACKAGE_NAME}.log"
IMPORT_LOG_FILE="${LOG_DIR}/gravity_package_ops_import_${PACKAGE_NAME}.log"
PACKAGE_CONTENT=$(timeout 1 tar tf ${PACKAGE} resources/app.yaml 2>/dev/null)

# Shift positionals to remove the package file name from script arguments
shift

if [ -n "${PACKAGE_CONTENT}" ]; then
     APP_VERSION=$(timeout 1 tar xf ${PACKAGE} resources/app.yaml --to-command "${BASEDIR}/yq r - metadata.resourceVersion; true")
     if [ -z "${APP_VERSION}" ]; then
       printf "Could not read '$APP_VERSION', exiting." | tee -a ${INSTALL_LOG_FILE}
       exit 1
     fi
     APP_NAME=$(timeout 1 tar xf ${PACKAGE} resources/app.yaml --to-command "${BASEDIR}/yq r - metadata.name; true")
     if [ -z "${APP_NAME}" ]; then
       printf "Could not read '$APP_NAME', exiting." | tee -a ${INSTALL_LOG_FILE}
       exit 1
     fi
     REPO_NAME=$(timeout 1 tar xf ${PACKAGE} resources/app.yaml --to-command "${BASEDIR}/yq r - metadata.repository; true")
     if [ -z "${REPO_NAME}" ]; then
       printf "Could not read '$REPO_NAME', exiting." | tee -a ${INSTALL_LOG_FILE}
       exit 1
     fi
     APP_STRING="${REPO_NAME}/${APP_NAME}:${APP_VERSION}"
     printf "#### Starting installation of ${APP_STRING} ...\n" | tee -a ${INSTALL_LOG_FILE}

    APP_IN_LIST=$(gravity package list | grep ${APP_STRING})
    
    PACKAGE_STAT=""
    if [ -n "${APP_IN_LIST}" ]; then
       APP_STAT=true 
    fi
    
  if [ -z "${APP_STAT}" ]; then
     printf "#### Connecting to Gravity Ops Center ...\n" | tee -a ${IMPORT_LOG_FILE}
     gravity ops connect --insecure https://localhost:3009 admin Passw0rd123 | tee -a ${IMPORT_LOG_FILE}
     printf "#### Pushing ${APP_STRING} to Gravity Ops Center ...\n" | tee -a ${IMPORT_LOG_FILE}
     gravity app import --force --insecure --ops-url=https://localhost:3009 ${PACKAGE} | tee -a ${IMPORT_LOG_FILE}
     printf "#### Exporting ${APP_STRING} to gravity Docker registry ...\n" | tee -a ${IMPORT_LOG_FILE}
     gravity exec gravity app export --insecure --ops-url=https://localhost:3009 ${APP_STRING}
  fi 

  printf "#### Executing ${APP_STRING} install hook ...\n" | tee -a ${IMPORT_LOG_FILE}
  gravity exec gravity app pull --force --insecure --ops-url=https://localhost:3009  ${APP_STRING} | tee -a ${IMPORT_LOG_FILE}

  printf "#### Executing ${APP_STRING} install hook ...\n" | tee -a ${INSTALL_LOG_FILE}
  gravity exec gravity app hook $@ ${APP_STRING} install | tee -a ${INSTALL_LOG_FILE}

  if [ $? -ne 0 ]; then
    echo "Error: hook for ${APP_STRING} exited with non-zero status." | tee -a ${INSTALL_LOG_FILE}
    exit 1
  fi
  printf "\n\nDone Installing App: ${APP_STRING} \n" | tee -a ${INSTALL_LOG_FILE}

else
  PACKAGE_CONTENT=$(timeout 1 tar tf ${PACKAGE} app.yaml 2>/dev/null)
  if [ -n "${PACKAGE_CONTENT}" ]; then
    printf "### Installing package ${PACKAGE} ...\n" | tee -a ${INSTALL_LOG_FILE}
    gravity app install $@ ${PACKAGE} | tee -a ${INSTALL_LOG_FILE}
  else
    printf "Not a valid Gravity package, exiting.\n" | tee -a ${INSTALL_LOG_FILE}
    exit 1
  fi
fi
