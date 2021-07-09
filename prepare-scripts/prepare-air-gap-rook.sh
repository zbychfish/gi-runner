#!/bin/bash

local_directory=`pwd`
host_fqdn=$( hostname --long )
air_dir=$local_directory/air-gap
# Creates temporary directory
mkdir -p $air_dir
dnf -qy install python3 podman wget
echo "Setup mirror image registry ..."
# - cleanup repository if exists
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
# - Pulls image of portable registry and save it 
podman pull docker.io/library/registry:2.6
# - Prepares portable registry directory structure
mkdir -p /opt/registry/{auth,certs,data}
# - Creates SSL cert for portable registry (only for mirroring, new one will be created in disconnected env)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/bastion.repo.pem -x509 -days 365 -out /opt/registry/certs/bastion.repo.crt -subj "/C=PL/ST=Miedzyrzecz/L=/O=Test /OU=Test/CN=`hostname --long`" -addext "subjectAltName = DNS:`hostname --long`"
cp /opt/registry/certs/bastion.repo.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
# - Creates user to get access to portable repository
dnf -qy install httpd-tools
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
podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:2.6
# Packs together centos updates, packages, python libraries and portable image
# Mirroring Rook-Ceph images (old version for all in one)
echo "Mirroring open source rook-ceph for onenode installation version 1.1.7 ..."
images="docker.io/rook/ceph:v1.1.7 quay.io/cephcsi/cephcsi:v1.2.1 quay.io/k8scsi/csi-node-driver-registrar:v1.1.0 quay.io/k8scsi/csi-provisioner:v1.3.0 quay.io/k8scsi/csi-snapshotter:v1.2.0 quay.io/k8scsi/csi-attacher:v1.2.0"
for image in $images
do
        echo $image
        podman pull $image
        tag=`echo "$image" | awk -F '/' '{print $NF}'`
        echo "TAG: $tag"
        podman save -o image.tar $image
        podman rmi $image
        podman load -i image.tar
        podman push --creds admin:guardium $image `hostname --long`:5000/rook/$tag 
	podman rmi $image
        rm -rf image.tar
done
# Archives mirrored images
echo "Mirroring open source rook-ceph for not onenode installation version 1.6.7 ..."
images="docker.io/ceph/ceph:v1.6.7 docker.io/ceph/ceph:v15.2.13 quay.io/cephcsi/cephcsi:v3.3.1 k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.2.0 k8s.gcr.io/sig-storage/csi-resizer:v1.2.0 k8s.gcr.io/sig-storage/csi-provisioner:v2.2.2 k8s.gcr.io/sig-storage/csi-snapshotter:v4.1.1 k8s.gcr.io/sig-storage/csi-attacher:v3.2.1"
for image in $images
do
	echo $image
        podman pull $image
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
echo "Rook-Ceph images prepared - copy file ${air_dir}/rook-registry-`date +%Y-%m-%d`.tar to air-gapped bastion machine"
