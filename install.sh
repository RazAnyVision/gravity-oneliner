#!/bin/bash
set -e
set -o pipefail

# script version
SCRIPT_VERSION="1.24.0-27"

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path to the script directory
BASEDIR=$(dirname "$SCRIPT")

# Network options
POD_NETWORK_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.172.0.0/16"

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


function cidr_overlap() (
  #check local cidr - This function was copied from the internet!
  subnet1="$1"
  subnet2="$2"
  
  # calculate min and max of subnet1
  # calculate min and max of subnet2
  # find the common range (check_overlap)
  # print it if there is one

  read_range () {
    IFS=/ read ip mask <<<"$1"
    IFS=. read -a octets <<< "$ip";
    set -- "${octets[@]}";
    min_ip=$(($1*256*256*256 + $2*256*256 + $3*256 + $4));
    host=$((32-mask))
    max_ip=$(($min_ip+(2**host)-1))
    printf "%d-%d\n" "$min_ip" "$max_ip"
  }

  check_overlap () {
    IFS=- read min1 max1 <<<"$1";
    IFS=- read min2 max2 <<<"$2";
    if [ "$max1" -lt "$min2" ] || [ "$max2" -lt "$min1" ]; then return; fi
    [ "$max1" -ge "$max2" ] && max="$max2" ||   max="$max1"
    [ "$min1" -le "$min2" ] && min="$min2" || min="$min1"
    printf "%s-%s\n" "$(to_octets $min)" "$(to_octets $max)"
  }

  to_octets () {
    first=$(($1>>24))
    second=$((($1&(256*256*255))>>16))
    third=$((($1&(256*255))>>8))
    fourth=$(($1&255))
    printf "%d.%d.%d.%d\n" "$first" "$second" "$third" "$fourth" 
  }

  range1="$(read_range $subnet1)"
  range2="$(read_range $subnet2)"
  overlap="$(check_overlap $range1 $range2)"
  [ -n "$overlap" ] && echo "Overlap $overlap of $subnet1 and $subnet2"

  # if cidr equal to install parameters exit 1 + echo notice to user
)

function cidr_check() {
  # This function:
  # checks if "DOWNLOAD_ONLY=true" is so returns normally
  # checks if there is CIDR overlap with local network
  # if there is an overlap it prints the details and terminates install script befor making changes

  if [[ "$DOWNLOAD_ONLY" == "false" ]]; then
    echo "Run with --download-only -> CIDR overlap check skipped!"
    return 0
  fi

  # evaluates the list of subnets using the "ip route" command and comparing each subnet to CIDR in use
  CIDR_LIST=$(ip route | cut -d' ' -f1)
  for network in $CIDR_LIST; do
    if [[ $network != "default" ]]; then
        # solve issue when mask is /32 and does not show in the ip route correctly
        IFS=/ read ip mask <<<"$network"
        if [[ ${mask} ]];then echo "OK"
          else
            network="$network/32"
            echo $network
        fi

        # calling function cidr_overlap to evaluate
        if [[ $( cidr_overlap ${POD_NETWORK_CIDR} ${network} ) ]]; then
          echo "Pods network CIDR Exist in network environment!!! Install terminated - nothing was done."
          cidr_overlap ${POD_NETWORK_CIDR} ${network}
          #echo "To run with custom CIDR use --pod-network-cidr"
          exit 1
        fi
        if [[ $( cidr_overlap ${SERVICE_CIDR} ${network} ) ]]; then
          echo "Service CIDR Exist in network environment!!! Install terminated - nothing was done."
          cidr_overlap ${SERVICE_CIDR} ${network}
          #echo "To run with custom CIDR use --service-cidr"
          exit 1
        fi
    fi
  done
}


  cidr_check



echo "=============================================================================================" | tee -a ${LOG_FILE}
echo "                                    Installation Completed!                                  " | tee -a ${LOG_FILE}
echo "=============================================================================================" | tee -a ${LOG_FILE}

if [ ${nvidia_installed} ]; then
  echo "                  New nvidia driver has been installed, Reboot is required!               " | tee -a ${LOG_FILE}
fi
