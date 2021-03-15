#!/bin/bash

local_directory=`pwd`
read -p "Insert OCP version to mirror (for example 4.6.19): " ocp_version
read -p "Insert RedHat pull secret: " pull_secret
echo "$pull_secret" > "pull-secret.txt"
read -p "Insert your mail address to authenticate in RedHat Network: " mail
read -p "Insert RH account name: " rh_account
read -sp "Insert RH account password: " rh_account_pwd
echo -e "\n"
while [[ $get_ics != 'Y' && $get_ics != 'N' ]]
do
        read -p "Do you need mirror ICS images? (Y/N): " get_ics
done
if [ $get_ics == 'Y' ]
then
        declare -a ics_versions=(3.5.6 3.6.2 3.6.3 3.7.1)
        while [[ ( -z $version_selected ) || ( $version_selected -lt 1 || $version_selected -gt $i ) ]]
        do
                echo "Select ICS version to mirror:"
                i=1
                for ics_version in "${ics_versions[@]}"
                do
                        echo "$i - $ics_version"
                        i=$((i+1))
                done
                read -p "Your choice?: " version_selected
        done
        version_selected=$(($version_selected-1))
fi
echo -e "\nPrepare TAR package for base OS ..."
dnf download -qy --downloaddir tar-install tar --resolve
ls tar-install/* | cpio -ov > download/tar.cpio
rm -rf tar-install
dnf -qy install tar
echo -e "Downloading CentOS updates ..."
dnf update -qy --downloadonly --downloaddir centos-updates
tar cf centos-updates-`date +%Y-%m-%d`.tar centos-updates
rm -rf centos-updates
echo "Downloading additional CentOS packages ..."
dnf -qy install epel-release
packages="ansible haproxy openldap perl podman-docker unzip ipxe-bootimgs skopeo chrony dnsmasq unzip wget jq"
for package in $packages
do
	dnf download -qy --downloaddir centos-packages $package --resolve
done
tar cf centos-packages-`date +%Y-%m-%d`.tar centos-packages 
rm -rf centos-packages
echo "Downloading python packages for Ansible extensions ..."
packages="passlib dnspython"
for package in $packages
do
	python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
done
tar cf ansible-`date +%Y-%m-%d`.tar ansible
rm -rf ansible
dnf -qy install httpd
echo "Setup mirror image registry ..."
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
podman pull docker.io/library/registry:2
podman save -o oc-registry.tar docker.io/library/registry:2
mkdir -p /opt/registry/{auth,certs,data}
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/bastion.repo.pem -x509 -days 365 -out /opt/registry/certs/bastion.repo.crt -subj "/C=PL/ST=Miedzyrzecz/L=/O=Test /OU=Test/CN=`hostname --long`" -addext "subjectAltName = DNS:`hostname --long`"
cp /opt/registry/certs/bastion.repo.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
htpasswd -bBc /opt/registry/auth/htpasswd admin guardium
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload
podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:2
semanage permissive -a NetworkManager_t
echo "Download OCP tools and CoreOS installation files ..."
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_version}/openshift-client-linux.tar.gz"
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_version}/openshift-install-linux.tar.gz"
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/latest/rhcos-live-initramfs.x86_64.img"
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/latest/rhcos-live-kernel-x86_64"
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/latest/rhcos-live-rootfs.x86_64.img"
wget "https://github.com/poseidon/matchbox/releases/download/v0.9.0/matchbox-v0.9.0-linux-amd64.tar.gz"
tar xf openshift-client-linux.tar.gz -C /usr/local/bin
host_fqdn=$( hostname --long )
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_version}/opm-linux.tar.gz"
tar xf opm-linux.tar.gz -C /usr/local/bin
tar cf download/tools.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img opm-linux.tar.gz matchbox-v0.9.0-linux-amd64.tar.gz
rm -rf openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img opm-linux.tar.gz matchbox-v0.9.0-linux-amd64.tar.gz
echo "Mirroring OCP ${ocp_version} images ..."
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
jq ".auths += $AUTHSTRING" < pull-secret.txt > pull-secret-update.txt
LOCAL_REGISTRY="$host_fqdn:5000"
LOCAL_REPOSITORY=ocp4/openshift4
PRODUCT_REPO='openshift-release-dev'
RELEASE_NAME="ocp-release"
LOCAL_SECRET_JSON='./pull-secret-update.txt'
ARCHITECTURE=x86_64
oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${ocp_version}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${ocp_version}-${ARCHITECTURE}
REDHAT_OPERATORS="local-storage-operator,ocs-operator"
CERTIFIED_OPERATORS="cert-manager-operator,nginx-ingress-operator,portworx-certified"
MARKETPLACE_OPERATORS="mongodb-enterprise-rhmp"
COMMUNITY_OPERATORS="portworx-essentials"
echo "Mirrorring Redhat Operators - ${REDHAT_OPERATORS} ..."
podman login $LOCAL_REGISTRY -u admin -p guardium
podman login registry.redhat.io -u "$rh_account" -p "$rh_account_pwd"
opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v4.6 -p $REDHAT_OPERATORS -t $LOCAL_REGISTRY/olm-v1/redhat-operator-index:v4.6
podman push $LOCAL_REGISTRY/olm-v1/redhat-operator-index:v4.6
oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/redhat-operator-index:v4.6 $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --filter-by-os=linux/amd64
echo "Mirrorring Certified Operators - ${CERTIFIED_OPERATORS} ..."
opm index prune -f registry.redhat.io/redhat/certified-operator-index:v4.6 -p $CERTIFIED_OPERATORS -t $LOCAL_REGISTRY/olm-v1/certified-operator-index:v4.6
podman push $LOCAL_REGISTRY/olm-v1/certified-operator-index:v4.6
oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/certified-operator-index:v4.6 $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --filter-by-os=linux/amd64
echo "Mirrorring Marketplace Operators - ${MARKETPLACE_OPERATORS} ..."
opm index prune -f registry.redhat.io/redhat/redhat-marketplace-index:v4.6 -p $MARKETPLACE_OPERATORS -t $LOCAL_REGISTRY/olm-v1/redhat-marketplace-index:v4.6
podman push $LOCAL_REGISTRY/olm-v1/redhat-marketplace-index:v4.6
oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/redhat-marketplace-index:v4.6 $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --filter-by-os=linux/amd64
echo "Mirrorring Community Operators - ${COMMUNITY_OPERATORS} ..."
opm index prune -f registry.redhat.io/redhat/community-operator-index:latest -p $COMMUNITY_OPERATORS -t $LOCAL_REGISTRY/olm-v1/community-operator-index:latest
podman push $LOCAL_REGISTRY/olm-v1/community-operator-index:latest
oc adm catalog mirror $LOCAL_REGISTRY/olm-v1/community-operator-index:latest $LOCAL_REGISTRY --insecure -a pull-secret-update.txt --filter-by-os=linux/amd64
mv manifests-redhat-operator-index-* manifests-redhat-operator-index
mv manifests-certified-operator-index-* manifests-certified-operator-index
mv manifests-redhat-marketplace-index-* manifests-redhat-marketplace-index
mv manifests-community-operator-index-* manifests-community-operator-index
tar cf download/manifests.tar manifests-*
rm -rf manifests-*
echo "Mirroring open source rook-ceph ..."
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
        podman push $image `hostname --long`:5000/rook/$tag
        rm -rf image.tar
done
if [ $get_ics == 'Y' ]
then
	echo "Mirroring ICS ${ics_versions[${version_selected}]}"
	dnf -y install skopeo
        wget https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz
        tar xf cloudctl-linux-amd64.tar.gz -C /usr/local/bin
        mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl
	mv cloudctl-linux-amd64.tar.gz download
        declare -a cases=(ibm-cp-common-services-1.1.16.tgz ibm-cp-common-services-1.2.2.tgz ibm-cp-common-services-1.2.3.tgz ibm-cp-common-services-1.3.1.tgz)
        CASE_ARCHIVE=${cases[${version_selected}]}
        CASE_INVENTORY_SETUP=ibmCommonServiceOperatorSetup
        cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/${CASE_ARCHIVE} --outputdir ics_offline
        sites="cp.icr.io registry.redhat.io registry.access.redhat.com"
        for site in $sites
        do
                echo $site
                cloudctl case launch --case ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry $site --user $rh_account --pass $rh_account_pwd"
        done
        cloudctl case launch --case ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry `hostname --long`:5000 --user admin --pass guardium"
        cloudctl case launch --case ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action mirror-images --args "--registry `hostname --long`:5000 --inputDir ics_offline"
	tar cf download/ics_offline-${ics_version}.tar ics_offline
	rm -rf ics_offline
fi
podman stop bastion-registry
echo "Archiving mirror registry ..."
cd /opt/registry
tar cf ${local_directory}/download/ocp-registry-with-olm-${ocp_version}.tar data
cd $local_directory
tar cf ${local_directory}/download/packages-`date +%Y-%m-%d`.tar centos-updates-* centos-packages-* ansible-* oc-registry.tar
rm -rf centos-updates-* centos-packages-* ansible-* oc-registry.tar
cd download
now_is=`date +%Y-%m-%d`
tar czpvf - *.tar cloudctl-linux-amd64.tar.gz | split -d -b 10G - air-gap-files-centos-`cat /etc/centos-release|awk '{print $NF}'`-ocp-release-${ocp_version}-ics-release-${ics_version}-${now_is}.tar
rm -rf *.tar cloudctl-linux-amd64.tar.gz
cd $local_directory
rm -rf pull-secret*
#mv air-gap-files-* download
rm -rf /opt/registry
podman rm bastion-registry
podman rmi --all
echo "AIR GAPPED FILES PREPARED"
