#!/bin/bash

#author: zibi - zszmigiero@gmail.com
[[ $# -eq 0 ]] && script_argument=0 && script_argument=$1
! [ -f ./prepare_offline.sh ] && { printf "This script must be executed from gi-runner home directoryi\n"; exit 1; }
# load functions
. ./funcs/functions.sh
# import global variables
. ./funcs/init.globals.sh

msg "This script collects all images and tools to deploy IBM Cloud Pak's in air-gapped environment" info
mkdir -p $GI_TEMP/airgap
[[ $script_argument -lt 1 ]] && prepare_bastion
[[ $script_argument -lt 1 ]] && prepare_ocp
msg "Airgap prescript summary" task
msg "In $GI_TEMP/download directory you have:" info
msg "- the latest gi-runner version (main branch) - gi-runner.zip" info
msg "- the unzip rpm package to install on target bastion to unpack gi-runner zip archive - unzip-<current_version>.x86_64.rpm" info
msg "- collected software packages for OS - os-<os_version>-<date_of_creation>.tar
