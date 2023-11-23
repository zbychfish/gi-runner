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
#get_mail "Provide e-mail address associated with just inserted RH pullSecret"
#mail=$curr_value
#msg "Setup mirror image registry ..." task
#msg "Save image registry image ..." task
#podman save -o $GI_TEMP/oc-registry.tar docker.io/library/registry:${registry_version} &>/dev/null
msg "Download OCP, support tools and CoreOS images ..." task
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
cat $GI_TEMP/pull-secret.txt | jq . > ${XDG_RUNTIME_DIR}/containers/auth.json
#LOCAL_REGISTRY="$host_fqdn:5000"
#LOCAL_REPOSITORY=ocp4/openshift4
#PRODUCT_REPO='openshift-release-dev'
#RELEASE_NAME="ocp-release"
#LOCAL_SECRET_JSON=$GI_TEMP/pull-secret-update.txt
#ARCHITECTURE=x86_64
mkdir -p $GI_TEMP/images
cp $GI_HOME/scripts/ocp-images.yaml $GI_TEMP
sed -i "s/stable-./fast-${ocp_major_release}/" $GI_TEMP/ocp-images.yaml
sed -i "s#.gitemp.#${GI_TEMP}#" $GI_TEMP/ocp-images.yaml
sed -i "s/minVersion/minVersion: ${ocp_release}/" $GI_TEMP/ocp-images.yaml
sed -i "s/maxVersion/maxVersion: ${ocp_release}/" $GI_TEMP/ocp-images.yaml
TMPDIR=$GI_TEMP/images oc mirror --config $GI_TEMP/ocp-images.yaml file://$GI_TEMP/images
test $(check_exit_code $?) && msg "OCP images mirrored" info || msg "Cannot mirror OCP images" info
mkdir -p ${air_dir}/${ocp_release}
mv $GI_TEMP/images/mirror_seq1* ${air_dir}/${ocp_release}
cd $GI_TEMP
tar -rf ${air_dir}/${ocp_release}/ocp-tools.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img "matchbox-v${matchbox_version}-linux-amd64.tar.gz" oc-mirror.tar.gz
#podman rm bastion-registry &>/dev/null
#podman rmi --all &>/dev/null
#rm -rf /opt/registry/data
#rm -f $GI_TEMP/pull-secret.txt
msg "Openshift images, installation files and tools prepared - copy directory ${air_dir}/${ocp_release} to air-gapped bastion machine to download one" info
rm -rf $GI_TEMP/images
