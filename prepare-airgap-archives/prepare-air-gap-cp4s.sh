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
if [ $# -eq 0 ]
then
        msg "Cleanup temp directory $temp_dir" info
        rm -rf $GI_TEMP/*
        mkdir -p $GI_TEMP
        mkdir -p $air_dir
fi
msg "Access to CP4S packages requires IBM Cloud account authentication for some container images" info
curr_value=""
while $(check_input "txt" "${curr_value}" "non_empty")
do
        get_input "txt" "Insert your IBM Cloud Key: " false
        curr_value="$input_variable"
done
ibm_account_pwd=$curr_value
mkdir -p $GI_TEMP/cp4s_arch
if [ $# -eq 0 ]
then
        msg "Setup mirror image registry ..." task
        setup_local_registry
        msg "Download support tools ..." task
        cd $GI_TEMP
        declare -a ocp_files=("https://github.com/IBM/ibm-pak/releases/download/v${ibm_ocp_pak_version}/oc-ibm_pak-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz" "https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz")
        for file in ${ocp_files[@]}
        do
                download_file $file
        done
        files_type="CP4S"
        install_app_tools
        dnf -qy install skopeo
        check_exit_code $? "Cannot install skopeo package"
fi
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
msg "Mirroring CP4S ${cp4s_versions}[0]" task
CASE_NAME="ibm-cp-security"
CASE_VERSION=${cp4s_cases[0]}
if [ $# -eq 0 ]
then
        msg "Downloading case file" info
        IBMPAK_HOME=${GI_TEMP} oc ibm-pak get $CASE_NAME --version $CASE_VERSION --skip-verify --disable-top-level-images-mode
        msg "Mirroring manifests" task
        IBMPAK_HOME=${GI_TEMP} oc ibm-pak generate mirror-manifests $CASE_NAME $LOCAL_REGISTRY --version $CASE_VERSION
        msg "Authenticate in cp.icr.io" info
        REGISTRY_AUTH_FILE=${GI_TEMP}/.ibm-pak/auth.json podman login cp.icr.io -u cp -p $ibm_account_pwd
        msg "Authenticate in local repo" info
        REGISTRY_AUTH_FILE=${GI_TEMP}/.ibm-pak/auth.json podman login `hostname --long`:5000 -u admin -p guardium
        get_latest_cp4s_images
fi
exit 1
msg "Starting mirroring images, can takes hours" info




if [ $# -eq 0 ]
then
	cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-security/${CASE_RELEASE}/${CASE_ARCHIVE} --outputdir $GI_TEMP/cp4s_arch/cp4s_offline
	check_exit_code $? "Cannot download GI case file"
	tar xvf $GI_TEMP/cp4s_arch/cp4s_offline/${CASE_ARCHIVE} -C $GI_TEMP/cp4s_arch/cp4s_offline
	#sed -i '/versionRegex/d' $GI_TEMP/cp4s_arch/cp4s_offline/ibm-cp-security/prereqs.yaml
	sites="cp.icr.io"
	for site in $sites
	do
		echo $site
	        cloudctl case launch --case $GI_TEMP/cp4s_arch/cp4s_offline/ibm-cp-security --action configure-creds-airgap --inventory $CASE_INVENTORY_SETUP --args "--registry $site --user cp --pass $ibm_account_key" --tolerance 1
		check_exit_code $? "Cannot configure credentials for site $site"
	done
	cloudctl case launch --case $GI_TEMP/cp4s_arch/cp4s_offline/ibm-cp-security --action configure-creds-airgap --inventory $CASE_INVENTORY_SETUP --args "--registry `hostname --long`:5000 --user admin --pass guardium" --tolerance 1
fi
cloudctl case launch --case $GI_TEMP/cp4s_arch/cp4s_offline/ibm-cp-security --action mirror-images --inventory $CASE_INVENTORY_SETUP --args "--registry `hostname --long`:5000 --inputDir $GI_TEMP/cp4s_arch/cp4s_offline" --tolerance 1
mirror_status=$?
msg "Mirroring status: $mirror_status" true
if [ $mirror_status -ne 0 ]
then
	echo "Mirroring process failed, restart script with parameter repeat to finish"
	exit 1
fi
podman stop bastion-registry
rm -rf $GI_TEMP/cp4s_arch/cp4s_offline/ibm-cp-security
cd $GI_TEMP
tar cf ${air_dir}/cp4s_registry-${cp4s_versions[0]}.tar cp4s_arch/cp4s_offline cloudctl-linux-amd64.tar.gz
cd /opt/registry
tar -rf ${air_dir}/cp4s_registry-${cp4s_versions[0]}.tar data
cd $GI_TEMP
rm -rf /opt/registry/data
podman rm bastion-registry
podman rmi --all
rm -rf $GI_TEMP
msg "CP4S ${cp4s_versions[0]} files prepared - copy $air_dir/cp4s_registry-${cp4s_versions[0]}.tar to air-gapped bastion machine" true
