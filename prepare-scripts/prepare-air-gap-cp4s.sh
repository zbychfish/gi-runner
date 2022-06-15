#!/bin/bash
set -e
trap "exit 1" ERR

echo "Setting environment"
if [[ $# -ne 0 && $1 != "repeat" ]]
then
	echo "To restart mirroring process use paramater 'repeat'"
	exit 1
fi

source scripts/init.globals.sh
source scripts/shared_functions.sh

get_pre_scripts_variables
if [ $# -eq 0 ]
then
	pre_scripts_init
fi
get_gi_version_prescript
gi_version=$(($gi_version-1))

if [ $# -eq 0 ]
then
	echo "Cleanup temp directory $temp_dir"
	rm -rf $GI_TEMP
	mkdir -p $GI_TEMP
	mkdir -p $air_dir
fi
read -sp "Insert your IBM Cloud Key: " ibm_account_key
if [ $# -eq 0 ]
then
	msg "Setup mirror image registry ..." true
	setup_local_registry
	msg "Download support tools ..." true
	cd $GI_TEMP
	declare -a ocp_files=("https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz")
	for file in ${ocp_files[@]}
	do
        	download_file $file
	done
	files_type="ICS"
	install_app_tools
	dnf -qy install skopeo
	check_exit_code $? "Cannot install skopeo package"
fi
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
echo "Mirroring GI ${gi_versions[${gi_version}]}"
CASE_ARCHIVE=${gi_cases[${gi_version}]}
CASE_INVENTORY_SETUP=install
if [ $# -eq 0 ]
then
	cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/${CASE_ARCHIVE} --outputdir $GI_TEMP/gi_offline
	check_exit_code $? "Cannot download GI case file"
	sites="cp.icr.io"
	for site in $sites
	do
		echo $site
	        cloudctl case launch --case $GI_TEMP/gi_offline/${CASE_ARCHIVE} --action configure-creds-airgap --inventory $CASE_INVENTORY_SETUP --args "--registry $site --user cp --pass $ibm_account_key"
		check_exit_code $? "Cannot configure credentials for site $site"
	done
	cloudctl case launch --case $GI_TEMP/gi_offline/${CASE_ARCHIVE} --action configure-creds-airgap --inventory $CASE_INVENTORY_SETUP --args "--registry `hostname --long`:5000 --user admin --pass guardium"
fi
cloudctl case launch --case $GI_TEMP/gi_offline/${CASE_ARCHIVE} --action mirror-images --inventory $CASE_INVENTORY_SETUP --args "--registry `hostname --long`:5000 --inputDir $GI_TEMP/gi_offline"
mirror_status=$?
echo "Mirroring status: $mirror_status"
if [ $mirror_status -ne 0 ]
then
	echo "Mirroring process failed, restart script with parameter repeat to finish"
	exit 1
fi
podman stop bastion-registry
cd $GI_TEMP
tar cf ${air_dir}/gi_registry-${gi_versions[${gi_version}]}.tar gi_offline cloudctl-linux-amd64.tar.gz
cd /opt/registry
tar -rf ${air_dir}/gi_registry-${gi_versions[${gi_version}]}.tar data
cd $GI_TEMP
rm -rf /opt/registry
podman rm bastion-registry
podman rmi --all
rm -rf $GI_TEMP
echo "GI ${gi_versions[${gi_version}]} files prepared - copy $air_dir/gi_registry-${gi_versions[${gi_version}]}.tar to air-gapped bastion machine"
