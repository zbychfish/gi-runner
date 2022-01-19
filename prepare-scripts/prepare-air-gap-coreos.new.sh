#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/shared_functions.sh

get_pre_scripts_variables
pre_scripts_init
msg "You must provide the exact version of OpenShift for its images mirror process" true
get_ocp_version_prescript
get_pull_secret
echo "$pull_secret" > $GI_TEMP/pull-secret.txt
get_mail "Provide e-mail address associated with just inserted RH pulSecret"
mail=curr_value
msg "Setup mirror image registry ..." true
setup_local_registry
msg "Save image registry image ..." true
podman save -o $GI_TEMP/oc-registry.tar docker.io/library/registry:${registry_version} &>/dev/null
msg "Download OCP, support tools and CoreOS images ..." true
cd $GI_TEMP
declare -a ocp_files=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-client-linux.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-install-linux.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-initramfs.x86_64.img" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-kernel-x86_64" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-rootfs.x86_64.img" "https://github.com/poseidon/matchbox/releases/download/v0.9.0/matchbox-v0.9.0-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz")
for file in ${ocp_files[@]}
do
	download_file $file
done
install_ocp_tools
msg "Mirroring OCP ${ocp_release} images ..."
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
jq ".auths += $AUTHSTRING" < $GI_TEMP/pull-secret.txt > $GI_TEMP/pull-secret-update.txt
LOCAL_REGISTRY="$host_fqdn:5000"
LOCAL_REPOSITORY=ocp4/openshift4
PRODUCT_REPO='openshift-release-dev'
RELEASE_NAME="ocp-release"
LOCAL_SECRET_JSON=$GI_TEMP/pull-secret-update.txt
ARCHITECTURE=x86_64
oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${ocp_release}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${ocp_release}-${ARCHITECTURE}
test $(check_exit_code $?) || msg "Cannot mirror OCP images" true
podman stop bastion-registry
cd /opt/registry
tar cf $air_dir/coreos-registry-${ocp_release}.tar data
cd $GI_TEMP
tar -rf $air_dir/coreos-registry-${ocp_release}.tar oc-registry.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img opm-linux.tar.gz matchbox-v0.9.0-linux-amd64.tar.gz
rm -rf $GI_TEMP
podman rm bastion-registry &>/dev/null
podman rmi --all &>/dev/null
rm -rf /opt/registry
rm -f $GI_TEMP/pull-secret.txt
msg "CoreOS images prepared - copy file ${air_dir}/coreos-registry-${ocp_release}.tar to air-gapped bastion machine" true
