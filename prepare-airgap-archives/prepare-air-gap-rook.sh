#!/bin/bash

set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/functions.sh

get_pre_scripts_variables
pre_scripts_init
msg "Gathering Rook-Ceph version details ..." task
ceph_path="deploy/examples"
images="docker.io/rook/ceph:${rook_version}"
cd $GI_TEMP
echo "ROOK_CEPH_OPER,docker.io/rook/ceph:${rook_version}" > $GI_TEMP/rook_images
dnf -qy install python3 podman wget git
check_exit_code $? "Cannot install required OS packages"
git clone https://github.com/rook/rook.git
cd rook
git checkout ${rook_version}
image=`grep -e "image:.*ceph\/ceph:.*" ${ceph_path}/cluster.yaml|awk '{print $NF}'`
images+=" "$image
echo "ROOK_CEPH_IMAGE,$image" >> $GI_TEMP/rook_images
declare -a labels=("ROOK_CSI_CEPH_IMAGE" "ROOK_CSI_REGISTRAR_IMAGE" "ROOK_CSI_RESIZER_IMAGE" "ROOK_CSI_PROVISIONER_IMAGE" "ROOK_CSI_SNAPSHOTTER_IMAGE" "ROOK_CSI_ATTACHER_IMAGE" "CSI_VOLUME_REPLICATION_IMAGE")
for label in "${labels[@]}"
do
        image=`cat ${ceph_path}/operator-openshift.yaml|grep $label|awk -F ":" '{print $(NF-1)":"$NF}'|tr -d '"'|tr -d " "`
        echo "$label,$image" >> $GI_TEMP/rook_images
        images+=" "$image
done
cd $GI_HOME
setup_local_registry
msg "Mirroring open source rook-ceph ${rook_version} ..." info
for image in $images
do
	msg "$image" true
        podman pull $image
	check_exit_code $? "Cannot pull image $image"
        tag=`echo "$image" | awk -F '/' '{print $NF}'`
        msg "TAG: $tag" info
	podman push --creds admin:guardium $image `hostname --long`:5000/rook/$tag
	podman rmi $image
done
labels+=("ROOK_CEPH_OPER")
labels+=("ROOK_CEPH_IMAGE")
echo "#List of rook-ceph images" > $GI_TEMP/rook_images_sha
for label in "${labels[@]}"
do
	IFS=":" read -r -a image_spec <<< `grep $label $GI_TEMP/rook_images|awk -F "," '{print $NF}'|awk -F "/" '{print $NF}'`
	echo `grep $label $GI_TEMP/rook_images`","`cat /opt/registry/data/docker/registry/v2/repositories/rook/${image_spec[0]}/_manifests/tags/${image_spec[1]}/current/link` >> $GI_TEMP/rook_images_sha
done
echo "Archiving mirrored registry ..."
podman stop bastion-registry
cd /opt/registry
tar cf ${air_dir}/rook-registry-${rook_version}.tar data
cd $GI_TEMP
tar -rf ${air_dir}/rook-registry-${rook_version}.tar rook_images_sha
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry/data
rm -rf $GI_TEMP
echo "Rook-Ceph images prepared - copy file ${air_dir}/rook-registry-${rook_version}.tar to air-gapped bastion machine"
