#!/bin/bash

#author: zibi - zszmigiero@gmail.com
[[ $# -eq 0 ]] && script_argument=0 || script_argument=$1
! [ -f ./prepare_offline.sh ] && { printf "This script must be executed from gi-runner home directoryi\n"; exit 1; }
# load functions
. ./funcs/functions.sh
# import global variables
. ./funcs/init.globals.sh

msg "This script collects all images and tools to deploy IBM Cloud Pak's in air-gapped environment" info
mkdir -p $GI_TEMP/airgap
[[ $script_argument -lt 1 ]] && prepare_bastion
rm -rf $GI_TEMP/airgap/*
[[ $script_argument -lt 2 ]] && prepare_ocp
rm -rf $GI_TEMP/airgap/* $GI_TEMP/images $GI_TEMP/ocp-images.yaml
[[ $script_argument -lt 3 ]] && prepare_rook
rm -rf $GI_TEMP/airgap/*
[[ $script_argument -lt 4 ]] && prepare_addons
rm -rf $GI_TEMP/airgap/*
[[ $script_argument -lt 5 ]] && prepare_apps

msg "Airgap prescript summary" task
msg "In $GI_TEMP/download directory you have:" info
msg "- the latest gi-runner version (main branch) - gi-runner.zip" info
msg "- the unzip rpm package to install on target bastion to unpack gi-runner zip archive - unzip-<current_version>.x86_64.rpm" info
msg "- collected software packages for OS - os-<os_version>-<date_of_creation>.tar" info
if [[ $script_argument -lt 2 ]]
then
	msg "- OCP and OLM images, OLM includes ODF and Serverless operators - OCP-${ocp_release}/ocp-images-data.tar" info
	msg "- Image Content Source Policy and Catalog Source for OLM - OCP-${ocp_release}/ocp-images-yamls.tar" info
	msg "- OCP tools and CoreOS installation files - OCP-${ocp_release}/ocp-tools.tar" info
	msg "- Docker registry ${registry_version} image - OCP-${ocp_release}/oc-registry.tar" info
fi
if [[ $script_argument -lt 3 ]]
then
        msg "- rook-ceph images and SHA's - rook-registry-${rook_operator_version}.tar" info
fi
if [[ $script_argument -lt 4 ]]
then
	msg "- images with additonal services NFS client, openldap - addons-registry-`date +%Y-%m-%d`.tar" info
fi
