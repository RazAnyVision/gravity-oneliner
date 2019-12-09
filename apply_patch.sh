#!/bin/bash
set -e
set -o pipefail

# script version
SCRIPT_VERSION="1.24.0-30"

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path to the script directory
BASEDIR=$(dirname "$SCRIPT")

INSTALL_METHOD="online"

LOG_FILE="/var/log/gravity-patch-installer.log"
S3_BUCKET_URL="https://gravity-bundles.s3.eu-central-1.amazonaws.com/hotfix-images"

# Gravity optios
SERVICE_NAME="service"
HOTFIX_VERSION="hotfix"

INSTALL_PRODUCT="false"
DOWNLOAD_ONLY="false"
FORCE_DOWNLOAD="false"

echo "------ Staring Gravity installer $(date '+%Y-%m-%d %H:%M:%S')  ------" >${LOG_FILE} 2>&1

## Permissions check
if [[ ${EUID} -ne 0 ]]; then
   echo "Error: This script must be run as root."
   echo "Installation failed, please contact support."
   exit 1
fi

## Get home Dir of the current user
if [ ${SUDO_USER} ]; then
  user=${SUDO_USER}
else
  user=`whoami`
fi

if [ "${user}" == "root" ]; then
  user_home_dir="/${user}"
else
  user_home_dir="/home/${user}"
fi

function showhelp {
   echo ""
   echo "Gravity Oneliner Patch Installer"
   echo ""
   echo "OPTIONS:"
   echo "  [-s|--service-name] Service name of the patch to load to the registry"
   echo "  [-v|--hotfix-version] Hotfix version to install (default: ${HOTFIX_VERSION})"
   echo "  [--download-only] Download all the required files (to ${BASEDIR})"
   echo "  [--force-download] Allow overwrite scripts if exist"
   echo "  [--base-url] Base URL for downloading the installation files (default: https://gravity-bundles.s3.eu-central-1.amazonaws.com)"
   echo "  [--auto-install-patch] Auto deploy patch after loading (from Rancher catalog)"
   echo ""
}

POSITIONAL=()
while test $# -gt 0; do
    key="$1"
    case $key in
        -h|help|--help)
        showhelp
        exit 0
        ;;
        --download-only)
            DOWNLOAD_ONLY="true"
        shift
        continue
        ;;
        --force-download)
            FORCE_DOWNLOAD="true"
        shift
        continue
        ;;
        -s|--service-name)
        shift
            SERVICE_NAME=${1:-$SERVICE_NAME}
        shift
        continue
        ;;
        -v|--hotfix-version)
        shift
            HOTFIX_VERSION=${1:-$HOTFIX_VERSION}
        shift
        continue
        ;;
        --auto-install-patch)
            INSTALL_PRODUCT="true"
        shift
        continue
        ;;
    esac
    break
done

function join_by() { local IFS="$1"; shift; echo "$*"; }

function download_patch() {
  echo "" | tee -a ${LOG_FILE}
  echo "======================================================================================" | tee -a ${LOG_FILE}
  echo "                Downloading Patch For ${SERVICE_NAME}, please wait...                 " | tee -a ${LOG_FILE}
  echo "======================================================================================" | tee -a ${LOG_FILE}
  echo "" | tee -a ${LOG_FILE}

  SERVICE_HOTFIX_URL="${S3_BUCKET_URL}/${SERVICE_NAME}/${SERVICE_NAME}_${HOTFIX_VERSION}.tar.gz"

  declare -a PACKAGES=("${SERVICE_HOTFIX_URL}")

  declare -a PACKAGES_TO_DOWNLOAD

  for url in "${PACKAGES[@]}"; do
    filename=$(echo "${url##*/}")
    PACKAGES_TO_DOWNLOAD+=("${url}")
  done

  DOWNLOAD_LIST=$(join_by " " "${PACKAGES_TO_DOWNLOAD[@]}")

  if [ "${DOWNLOAD_LIST}" ]; then
    echo "#### Downloading Files ..." | tee -a ${LOG_FILE}
    echo "Downloading Files: $DOWNLOAD_LIST" >>${LOG_FILE} 2>&1
    gravity exec wget ${DOWNLOAD_LIST}
    #gravity exec aria2c --summary-interval=30 --force-sequential --auto-file-renaming=false --min-split-size=100M --split=10 --max-concurrent-downloads=5 --check-certificate=false ${DOWNLOAD_LIST}
  else
    echo "#### All the packages are already exist" | tee -a ${LOG_FILE}
  fi

}

function load_patch() {
  echo "" | tee -a ${LOG_FILE}
  echo "==============================================================" | tee -a ${LOG_FILE}
  echo "==           Loading Service Into Local Registry...         ==" | tee -a ${LOG_FILE}
  echo "==============================================================" | tee -a ${LOG_FILE}
  echo "" | tee -a ${LOG_FILE}
  gravity exec gzip -d ${SERVICE_NAME}_${HOTFIX_VERSION}.tar.gz
  gravity exec docker load -i ${SERVICE_NAME}_${HOTFIX_VERSION}.tar
}

## Remove patch files if already existed
gravity exec rm -rf ${SERVICE_NAME}_${HOTFIX_VERSION}.tar*

echo "Uploading Hotfix: ${SERVICE_NAME}_${HOTFIX_VERSION}.tar.gz to local registry" | tee -a ${LOG_FILE}

if [[ "${INSTALL_METHOD}" == "online" ]]; then
  download_patch
  if [ "${DOWNLOAD_ONLY}" == "true" ]; then
    echo "#### Download only is enabled. will exit" | tee -a ${LOG_FILE}
    exit 0
  fi
fi

load_patch

echo "=============================================================================================" | tee -a ${LOG_FILE}
echo "                                    Installation Completed!                                  " | tee -a ${LOG_FILE}
echo "=============================================================================================" | tee -a ${LOG_FILE}
