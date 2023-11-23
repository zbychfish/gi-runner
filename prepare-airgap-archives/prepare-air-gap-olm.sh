#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/functions.sh

get_pre_scripts_variables
pre_scripts_init
msg "Select OCP release for which OLM packages must be prepared" info
get_ocp_version_prescript "major"
get_pull_secret
#msg "Access to OLM packages requires RedHat account authentication" true
#get_account "Insert RedHat account name"
#rh_account=$curr_value
echo "$rhn_secret" > $GI_TEMP/pull-secret.txt
#curr_value=""
#while $(check_input "${curr_value}" "txt" 2)
#do
#	get_input "txt" "Insert password for RedHat account $rh_account: " false
#        curr_value="$input_variable"
#done
#rh_account_pwd=$curr_value
#olm_for_cp4s=""
#while $(check_input "$olm_for_cp4s" "yn" false)
#do
#	get_input "yn" "Do you plan install CP4S?: " true
#        olm_for_cp4s=${input_variable^^}
#done
#msg "Setup mirror image registry ..." true
#setup_local_registry
msg "Download support tools ..." task
cd $GI_TEMP
declare -a ocp_files=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/oc-mirror.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-${ocp_major_release}/openshift-client-linux.tar.gz")
for file in ${ocp_files[@]}
do
        download_file $file
done
install_ocp_tools
rm -f openshift-client-linux.tar.gz oc-mirror.tar.gz
#msg "Patching GPG keys ..." true
#curl -s -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv https://www.redhat.com/security/data/55A34A82.txt
#cat /etc/containers/policy.json|jq '.transports += {"docker": {"registry.redhat.io/redhat/certified-operator-index": [{"type": "signedBy","keyType": "GPGKeys","keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv"}],"registry.redhat.io/redhat/community-operator-index": [{"type": "insecureAcceptAnything"}],"registry.redhat.io/redhat/redhat-marketplace-index": [{"type": "signedBy","keyType": "GPGKeys","keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv"}]}}' > /etc/containers/policy-new.json
#mv -f /etc/containers/policy-new.json /etc/containers/policy.json
msg "Mirroring OLM ${ocp_major_release} images ..." task
#LOCAL_REGISTRY="$host_fqdn:5000"

#declare -a ocp_by_ocs=("4.6" "4.7" "4.8")
rh_operators=("local-storage-operator" "odf-operator" "ocs-operator" "mcg-operator" "odf-csi-addons-operator" "serverless-operator" "web-terminal")
#if  grep -q ${ocp_major_release} <<< ${ocp_by_ocs[@]}
#then
#	native_storage_operator="ocs-operator"
#else
#	native_storage_operator="odf-operator,ocs-operator,mcg-operator,odf-csi-addons-operator"
#fi
#if [[ ! -z "$REDHAT_OPERATORS_OVERRIDE" ]]
#then
#	REDHAT_OPERATORS=$REDHAT_OPERATORS_OVERRIDE
#else
#	if [ "${olm_for_cp4s}" == 'Y' ]
#	then
#		REDHAT_OPERATORS="local-storage-operator,${native_storage_operator},serverless-operator,web-terminal"
#	else
#		REDHAT_OPERATORS="local-storage-operator,${native_storage_operator},web-terminal"
#	fi
#fi
#if [[ ! -z "$CERTIFIED_OPERATORS_OVERRIDE" ]]
#then
#	CERTIFIED_OPERATORS=$CERTIFIED_OPERATORS_OVERRIDE
#else
#	CERTIFIED_OPERATORS=""
#fi
#if [[ ! -z "$MARKETPLACE_OPERATORS_OVERRIDE" ]]
#then
#	MARKETPLACE_OPERATORS=$MARKETPLACE_OPERATORS_OVERRIDE
#else
#	MARKETPLACE_OPERATORS=""
#fi
#if [[ ! -z "$COMMUNITY_OPERATORS_OVERRIDE" ]]
#then
#	COMMUNITY_OPERATORS=$COMMUNITY_OPERATORS_OVERRIDE
#else
#	COMMUNITY_OPERATORS=""
#fi
#b64auth=$( echo -n 'admin:guardium' | openssl base64 )
#AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
#jq ".auths += $AUTHSTRING" < $GI_TEMP/pull-secret.txt > $GI_TEMP/pull-secret-update.txt
#LOCAL_REGISTRY="$host_fqdn:5000"
#echo $REDHAT_OPERATORS > $air_dir/operators.txt
#echo $CERTIFIED_OPERATORS >> $air_dir/operators.txt
#echo $MARKETPLACE_OPERATORS >> $air_dir/operators.txt
#echo $COMMUNITY_OPERATORS >> $air_dir/operators.txt
# - Mirrroring process
podman login $LOCAL_REGISTRY -u admin -p guardium
check_exit_code $? "Cannot login to local image registry"
podman login registry.redhat.io -u "$rh_account" -p "$rh_account_pwd"
check_exit_code $? "Cannot login to RedHat image repository"
if [[ ${REDHAT_OPERATORS} != "" ]]
then
	msg "Mirrorring RedHat Operators - ${REDHAT_OPERATORS} ..." true
	opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v${ocp_major_release} -p $REDHAT_OPERATORS -t $LOCAL_REGISTRY/olm-v1/redhat-operator-index:v${ocp_major_release}
	podman push $LOCAL_REGISTRY/olm-v1/redhat-operator-index:v${ocp_major_release}
	oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/redhat-operator-index:v${ocp_major_release} $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --index-filter-by-os="linux/amd64"
	check_exit_code $? "Error during mirroring of RedHat operators"
	mv manifests-redhat-operator-index-* manifests-redhat-operator-index
fi
if [[ ${CERTIFIED_OPERATORS} != "" ]]
then
	msg "Mirrorring Certified Operators - ${CERTIFIED_OPERATORS} ..." true
	opm index prune -f registry.redhat.io/redhat/certified-operator-index:v${ocp_major_release} -p $CERTIFIED_OPERATORS -t $LOCAL_REGISTRY/olm-v1/certified-operator-index:v${ocp_major_release}
	podman push $LOCAL_REGISTRY/olm-v1/certified-operator-index:v${ocp_major_release}
	oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/certified-operator-index:v${ocp_major_release} $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --index-filter-by-os="linux/amd64"
	check_exit_code $? "Error during mirroring of RedHat operators"
	mv manifests-certified-operator-index-* manifests-certified-operator-index
fi
if [[ ${MARKETPLACE_OPERATORS} != "" ]]
then
	msg "Mirrorring Marketplace Operators - ${MARKETPLACE_OPERATORS} ..." true
	opm index prune -f registry.redhat.io/redhat/redhat-marketplace-index:v${ocp_major_release} -p $MARKETPLACE_OPERATORS -t $LOCAL_REGISTRY/olm-v1/redhat-marketplace-index:v${ocp_major_release}
	podman push $LOCAL_REGISTRY/olm-v1/redhat-marketplace-index:v${ocp_major_release}
	oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/redhat-marketplace-index:v${ocp_major_release} $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --index-filter-by-os="linux/amd64"
	check_exit_code $? "Error during mirroring of RedHat operators"
	mv manifests-redhat-marketplace-index-* manifests-redhat-marketplace-index
fi
if [[ ${COMMUNITY_OPERATORS} != "" ]]
then
	msg "Mirrorring Community Operators - ${COMMUNITY_OPERATORS} ..." true
	opm index prune -f registry.redhat.io/redhat/community-operator-index:latest -p $COMMUNITY_OPERATORS -t $LOCAL_REGISTRY/olm-v1/community-operator-index:latest
	podman push $LOCAL_REGISTRY/olm-v1/community-operator-index:latest
	oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/community-operator-index:latest $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --index-filter-by-os="linux/amd64"
	check_exit_code $? "Error during mirroring of RedHat operators"
	mv manifests-community-operator-index-* manifests-community-operator-index
fi
# - Archvining manifests
# - Clean up
podman stop bastion-registry
cd /opt/registry
tar cf $air_dir/olm-registry-${ocp_major_release}-for-gi-`date +%Y-%m-%d`.tar data
cd $GI_TEMP
tar -rf $air_dir/olm-registry-${ocp_major_release}-for-gi-`date +%Y-%m-%d`.tar manifests-*
cd $air_dir
tar -rf $air_dir/olm-registry-${ocp_major_release}-for-gi-`date +%Y-%m-%d`.tar operators.txt
rm -rf $GI_TEMP
rm -f  $air_dir/operators.txt
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry/data
if [ "${olm_for_cp4s}" == 'Y' ]
then
	mv $air_dir/olm-registry-${ocp_major_release}-for-gi-`date +%Y-%m-%d`.tar $air_dir/olm-registry-${ocp_major_release}-for-gi-and-cp4s-`date +%Y-%m-%d`.tar
fi
msg "OLM images prepared for ${ocp_major_release} - copy $air_dir/olm-registry-${ocp_major_release}-*.tar to air-gapped bastion machine" true
