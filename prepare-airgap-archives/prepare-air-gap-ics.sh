#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/functions.sh

get_pre_scripts_variables
pre_scripts_init
get_ics_version_prescript
ics_version=$(($ics_version-1))
msg "Access to ICS packages requires RedHat account authentication for some container images" info
get_account "Insert RedHat account name"
rh_account=$curr_value
echo "$rhn_secret" > $GI_TEMP/pull-secret.txt
curr_value=""
while $(check_input "txt" "${curr_value}" "non_empty")
do
        get_input "txt" "Insert password for RedHat account $rh_account: " false
        curr_value="$input_variable"
done
rh_account_pwd=$curr_value
msg "Access to ICS packages requires IBM Cloud account authentication for some container images" info
curr_value=""
while $(check_input "txt" "${curr_value}" "non_empty")
do
        get_input "txt" "Insert your IBM Cloud Key: " false
        curr_value="$input_variable"
done
ibm_account_pwd=$curr_value
msg "Setup mirror image registry ..." task
setup_local_registry
msg "Download support tools ..." task
cd $GI_TEMP
declare -a ocp_files=("https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz")
for file in ${ocp_files[@]}
do
        download_file $file
done
files_type="ICS"
install_app_tools
rm -f openshift-client-linux.tar.gz
msg "Mirroring ICS ${ics_versions[${ics_version}]}" task
dnf -qy install skopeo
check_exit_code $? "Cannot install skopeo package"
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
CASE_ARCHIVE=${ics_cases[${ics_version}]}
CASE_RELEASE=${CASE_ARCHIVE#"ibm-cp-common-services-"}
CASE_RELEASE=${CASE_RELEASE%".tgz"}
CASE_INVENTORY_SETUP=ibmCommonServiceOperatorSetup
cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-common-services/${CASE_RELEASE}/${CASE_ARCHIVE} --outputdir $GI_TEMP/ics_offline
check_exit_code $? "Cannot download ICS case file"
sites="registry.redhat.io registry.access.redhat.com"
for site in $sites
do
	echo $site
        cloudctl case launch --case $GI_TEMP/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry $site --user $rh_account --pass $rh_account_pwd"
	check_exit_code $? "Cannot configure credentials for site $site"
done
cloudctl case launch --case $GI_TEMP/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry cp.icr.io --user cp --pass $ibm_account_pwd"
check_exit_code $? "Cannot configure credentials for site cp.icr.io"
cloudctl case launch --case $GI_TEMP/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry `hostname --long`:5000 --user admin --pass guardium"
check_exit_code $? "Cannot configure credentials for local registry"
msg "Starting images copying process, it can takes more than one hour" task
cloudctl case launch --case $GI_TEMP/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action mirror-images --args "--registry `hostname --long`:5000 --inputDir $GI_TEMP/ics_offline"
check_exit_code $? "Cannot mirror ICS images"
msg "Preparing images archive" task
podman stop bastion-registry
cd /opt/registry
tar cf ${air_dir}/ics_registry-${ics_versions[${ics_version}]}.tar data
cd $GI_TEMP
tar -rf ${air_dir}/ics_registry-${ics_versions[${ics_version}]}.tar ics_offline cloudctl-linux-amd64.tar.gz
# Cleanup gi-temp, portable-registry
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry/data
rm -rf $GI_TEMP
msg "ICS ${ics_versions[${ics_version}]} files prepared - copy $air_dir/ics_registry-${ics_versions[${ics_version}]}.tar to air-gapped bastion machine" info
