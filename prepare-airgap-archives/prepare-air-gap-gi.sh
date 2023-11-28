#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/functions.sh
get_pre_scripts_variables
msg "Setting environment" info
if [[ $# -ne 0 && $1 != "repeat" ]]
then
	msg "To restart mirroring process use paramater 'repeat'" info
	exit 1
fi
if [ $# -eq 0 ]
then
	pre_scripts_init
fi
get_gi_version_prescript
gi_version=$(($gi_version-1))
if [ $# -eq 0 ]
then
	msg "Cleanup temp directory $temp_dir" info
	rm -rf $GI_TEMP/*
	mkdir -p $GI_TEMP
	mkdir -p $air_dir
fi
msg "Access to GI packages requires IBM Cloud account authentication for some container images" info
curr_value=""
while $(check_input "txt" "${curr_value}" "non_empty")
do
        get_input "txt" "Insert your IBM Cloud Key: " false
        curr_value="$input_variable"
done
ibm_account_pwd=$curr_value
if [ $# -eq 0 ]
then
	msg "Setup mirror image registry ..." task
	setup_local_registry
	msg "Download support tools ..." task
	cd $GI_TEMP
	declare -a ocp_files=("https://github.com/IBM/ibm-pak/releases/download/v${ibm_ocp_pak_version}/oc-ibm_pak-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz")
	for file in ${ocp_files[@]}
	do
        	download_file $file
	done
	files_type="GI"
	install_app_tools
	dnf -qy install skopeo
	check_exit_code $? "Cannot install skopeo package"
fi
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
msg "Mirroring GI ${gi_versions[${gi_version}]}" task
msg "Download case file" info
CASE_NAME="ibm-guardium-insights"
CASE_VERSION=${gi_cases[${gi_version}]}
IBMPAK_HOME=${GI_TEMP}/ibm_pak
IBMPAK_HOME=${IBMPAK_HOME} oc ibm-pak get $CASE_NAME --version $CASE_VERSION --skip-verify
exit 1
if [ $# -eq 0 ]
then
	cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-guardium-insights/${CASE_RELEASE}/${CASE_ARCHIVE} --outputdir $GI_TEMP/gi_offline
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
msg "Mirroring status: $mirror_status" true
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
rm -rf /opt/registry/data
podman rm bastion-registry
podman rmi --all
rm -rf $GI_TEMP
msg "GI ${gi_versions[${gi_version}]} files prepared - copy $air_dir/gi_registry-${gi_versions[${gi_version}]}.tar to air-gapped bastion machine" true
