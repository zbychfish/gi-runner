#!/bin/bash
rook_version="v1.8.0"
images="docker.io/rook/ceph:${rook_version}"
local_directory=`pwd`
temp_dir=$local_directory/gi-temp
cd $temp_dir
echo "ROOK_CEPH_OPER,docker.io/rook/ceph:${rook_version}" > $temp_dir/rook_images
dnf -y install git
git clone https://github.com/rook/rook.git
cd rook
git checkout ${rook_version}
image=" "`grep -e "image:.*ceph\/ceph:.*" deploy/examples/cluster.yaml|awk '{print $NF}'`
images+=image
echo "ROOK_CEPH_IMAGE,$image" >> $temp_dir/rook_images
declare -a labels=("ROOK_CSI_CEPH_IMAGE" "ROOK_CSI_REGISTRAR_IMAGE" "ROOK_CSI_RESIZER_IMAGE" "ROOK_CSI_PROVISIONER_IMAGE" "ROOK_CSI_SNAPSHOTTER_IMAGE" "ROOK_CSI_ATTACHER_IMAGE" "CSI_VOLUME_REPLICATION_IMAGE")
for label in "${labels[@]}"
do
	cat deploy/examples/operator-openshift.yaml|grep $label|awk -F ":" '{print $(NF-1)":"$NF}'|tr -d '"'|tr -d " "
done
echo $images
exit 0
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

echo "Setting environment"
registry_version=2.7.1
local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates temporary directory
mkdir -p $air_dir
dnf -qy install python3 podman wget
check_exit_code $? "Cannot install required OS packages"
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
echo "Mirroring open source rook-ceph for not onenode installation version 1.6.7 ..."
images="docker.io/rook/ceph:v1.7.6 quay.io/ceph/ceph:v16.2.6 quay.io/cephcsi/cephcsi:v3.4.0 k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.3.0 k8s.gcr.io/sig-storage/csi-resizer:v1.3.0 k8s.gcr.io/sig-storage/csi-provisioner:v3.0.0 k8s.gcr.io/sig-storage/csi-snapshotter:v4.2.0 k8s.gcr.io/sig-storage/csi-attacher:v3.3.0"
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
echo "Archiving mirrored registry ..."
podman stop bastion-registry
cd /opt/registry
tar cf ${air_dir}/rook-registry-`date +%Y-%m-%d`.tar data
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry
rm -rf $temp_dir
echo "Rook-Ceph images prepared - copy file ${air_dir}/rook-registry-`date +%Y-%m-%d`.tar to air-gapped bastion machine"
