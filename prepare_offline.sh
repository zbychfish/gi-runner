#!/bin/bash

#author: zibi - zszmigiero@gmail.com

# load functions
. ./funcs/functions.sh
# import global variables
. ./funcs/init.globals.sh

msg "This script collects all images and tools to deploy IBM Cloud Pak's in air-gapped environment" info
mkdir -p $GI_TEMP/airgap
prepare_bastion
