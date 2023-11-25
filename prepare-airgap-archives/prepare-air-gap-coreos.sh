#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/functions.sh

get_pre_scripts_variables
pre_scripts_init
msg "You must provide the exact version of OpenShift for its images mirror process" info
msg "It is suggested to install a release from stable repository" info
get_ocp_version_prescript
get_pull_secret
echo "$rhn_secret" > $GI_TEMP/pull-secret.txt
msg "Installing podman, httpd-tools jq openssl policycoreutils-python-utils ..." task
dnf -qy install podman httpd-tools openssl jq policycoreutils-python-utils
test $(check_exit_code $?) || (msg "Cannot install httpd-tools" info; exit 1)
msg "Download a mirror image registry ..." task
podman pull docker.io/library/registry:${registry_version} &>/dev/null
test $(check_exit_code $?) || (msg "Cannot download image registry" true; exit 1)
msg "Save image registry image ..." task
podman save -o $GI_TEMP/oc-registry.tar docker.io/library/registry:${registry_version} &>/dev/null
podman rmi --all &>/dev/null
#get_mail "Provide e-mail address associated with just inserted RH pullSecret"
#mail=$curr_value
#msg "Setup mirror image registry ..." task
msg "Download OCP, support tools and CoreOS images ..." task
dnf -qy install wget
cd $GI_TEMP
declare -a ocp_files=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-client-linux.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-install-linux.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-initramfs.x86_64.img" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-kernel-x86_64" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-rootfs.x86_64.img" "https://github.com/poseidon/matchbox/releases/download/v${matchbox_version}/matchbox-v${matchbox_version}-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/oc-mirror.tar.gz")
for file in ${ocp_files[@]}
do
	download_file $file
done
install_ocp_tools
#msg "Mirroring OCP ${ocp_release} images ..." task
#b64auth=$( echo -n 'admin:guardium' | openssl base64 )
#AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
#jq ".auths += $AUTHSTRING" < $GI_TEMP/pull-secret.txt > $GI_TEMP/pull-secret-update.txt
mkdir -p /run/user/0/containers #if podman was not initiated yet
cat $GI_TEMP/pull-secret.txt | jq . > ${XDG_RUNTIME_DIR}/containers/auth.json
#LOCAL_REGISTRY="$host_fqdn:5000"
#LOCAL_REPOSITORY=ocp4/openshift4
#PRODUCT_REPO='openshift-release-dev'
#RELEASE_NAME="ocp-release"
#LOCAL_SECRET_JSON=$GI_TEMP/pull-secret-update.txt
#ARCHITECTURE=x86_64
mkdir -p $GI_TEMP/images
cp $GI_HOME/scripts/ocp-images.yaml $GI_TEMP
sed -i "s/.ocp_version./${ocp_major_release}/" $GI_TEMP/ocp-images.yaml
sed -i "s#.gitemp.#${GI_TEMP}#" $GI_TEMP/ocp-images.yaml
sed -i "s/minVersion/minVersion: ${ocp_release}/" $GI_TEMP/ocp-images.yaml
sed -i "s/maxVersion/maxVersion: ${ocp_release}/" $GI_TEMP/ocp-images.yaml
msg "Starting image mirroring ..." task
TMPDIR=$GI_TEMP/images oc mirror --config $GI_TEMP/ocp-images.yaml file://$GI_TEMP/images
test $(check_exit_code $?) && msg "OCP images mirrored" info || msg "Cannot mirror OCP images" info
msg "Mirroring finished succesfully" info
mkdir -p ${air_dir}/${ocp_release}
mv $GI_TEMP/images/mirror_* ${air_dir}/${ocp_release}
cd $GI_TEMP
tar -rf ${air_dir}/${ocp_release}/ocp-tools.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img "matchbox-v${matchbox_version}-linux-amd64.tar.gz" oc-mirror.tar.gz oc-registry.tar
#podman rm bastion-registry &>/dev/null
#rm -rf /opt/registry/data
#rm -f $GI_TEMP/pull-secret.txt
msg "Openshift images, installation files and tools prepared - copy directory ${air_dir}/${ocp_release} to air-gapped bastion machine to download one" info
msg "Limited number OLM operators have been downloaded: local-storage-operator, odf-operator, ocs-operator, mcg-operator, odf-csi-addons-operator, serverless-operator, web-terminal" info
msg "You can add more operators by modification of file scripts/ocp-images.yaml" info
rm -rf $GI_TEMP/*
