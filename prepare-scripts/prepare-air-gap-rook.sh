#!/bin/bash

function check_exit_code() {
        if [[ $1 -ne 0 ]]
        then
                echo $2
                echo "Please check the reason of problem and restart script"
                exit 1
        else
                echo "OK"
        fi
}

registry_version=2.7.1
rook_version="v1.8.0"
host_fqdn=$( hostname --long )
images="docker.io/rook/ceph:${rook_version}"
local_directory=`pwd`
air_dir=$local_directory/air-gap
temp_dir=$local_directory/gi-temp
mkdir -p $temp_dir
cd $temp_dir
echo "ROOK_CEPH_OPER,docker.io/rook/ceph:${rook_version}" > $temp_dir/rook_images
dnf -qy install python3 podman wget git
check_exit_code $? "Cannot install required OS packages"
git clone https://github.com/rook/rook.git
cd rook
git checkout ${rook_version}
image=`grep -e "image:.*ceph\/ceph:.*" deploy/examples/cluster.yaml|awk '{print $NF}'`
images+=" "$image
echo "ROOK_CEPH_IMAGE,$image" >> $temp_dir/rook_images
declare -a labels=("ROOK_CSI_CEPH_IMAGE" "ROOK_CSI_REGISTRAR_IMAGE" "ROOK_CSI_RESIZER_IMAGE" "ROOK_CSI_PROVISIONER_IMAGE" "ROOK_CSI_SNAPSHOTTER_IMAGE" "ROOK_CSI_ATTACHER_IMAGE" "CSI_VOLUME_REPLICATION_IMAGE")
for label in "${labels[@]}"
do
        image=`cat deploy/examples/operator-openshift.yaml|grep $label|awk -F ":" '{print $(NF-1)":"$NF}'|tr -d '"'|tr -d " "`
        echo "$label,$image" >> $temp_dir/rook_images
        images+=" "$image
done
cd $local_directory
echo "Setting environment"
# Creates temporary directory
mkdir -p $air_dir
echo "Setup mirror image registry ..."
# - cleanup repository if exists
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
# - Pulls image of portable registry and save it 
podman pull docker.io/library/registry:${registry_version}
check_exit_code $? "Cannot download image registry"
# - Prepares portable registry directory structure
mkdir -p /opt/registry/{auth,certs,data}
# - Creates SSL cert for portable registry (only for mirroring, new one will be created in disconnected env)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/bastion.repo.pem -x509 -days 365 -out /opt/registry/certs/bastion.repo.crt -subj "/C=PL/ST=Miedzyrzecz/L=/O=Test /OU=Test/CN=`hostname --long`" -addext "subjectAltName = DNS:`hostname --long`"
check_exit_code $? "Cannot create certificate for temporary image registry"
cp /opt/registry/certs/bastion.repo.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
# - Creates user to get access to portable repository
dnf -qy install httpd-tools
check_exit_code $? "Cannot install httpd-tools"
htpasswd -bBc /opt/registry/auth/htpasswd admin guardium
# - Sets firewall settings
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload
# - Sets SE Linux for NetworkManager
semanage permissive -a NetworkManager_t
# - Starts portable registry
echo "Starting mirror image registry ..."
podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:${registry_version}
check_exit_code $? "Cannot start temporary image registry"
# Packs together centos updates, packages, python libraries and portable image
echo "Mirroring open source rook-ceph ${rook_version} ..."
for image in $images
do
	echo $image
        podman pull $image
	check_exit_code $? "Cannot pull image $image"
        tag=`echo "$image" | awk -F '/' '{print $NF}'`
        echo "TAG: $tag"
	podman push --creds admin:guardium $image `hostname --long`:5000/rook/$tag
	podman rmi $image
done
labels+=("ROOK_CEPH_OPER")
labels+=("ROOK_CEPH_IMAGE")
for label in "${labels[@]}"
do
	IFS=":" read -r -a image_spec <<< `grep $label $temp_dir/rook_images|awk -F "," '{print $NF}'|awk -F "/" '{print $NF}'`
	echo `grep $label $temp_dir/rook_images`","`cat /opt/registry/data/docker/registry/v2/repositories/rook/${image_spec[0]}/_manifests/tags/${image_spec[1]}/current/link` >> $temp_dir/rook_images_sha
done
exit 0
echo "Archiving mirrored registry ..."
podman stop bastion-registry
cd /opt/registry
tar cf ${air_dir}/rook-registry-${rook_version}.tar data
cd $temp_dir
tar -rf ${air_dir}/rook-registry-${rook_version}.tar rook_images_sha
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry
rm -rf $temp_dir
echo "Rook-Ceph images prepared - copy file ${air_dir}/rook-registry-${rook_version}.tar to air-gapped bastion machine"
