#!/bin/bash

local_directory=`pwd`
host_fqdn=$( hostname --long )
# Creates target download directory
mkdir -p download
# Creates temporary directory
mkdir -p gi-temp
# Gets list of parameters to create repo
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
        while [[ ( -z $ics_version_selected ) || ( $ics_version_selected -lt 1 || $ics_version_selected -gt $i ) ]]
        do
                echo "Select ICS version to mirror:"
                i=1
                for ics_version in "${ics_versions[@]}"
                do
                        echo "$i - $ics_version"
                        i=$((i+1))
                done
                read -p "Your choice?: " ics_version_selected
        done
        ics_version_selected=$(($ics_version_selected-1))
fi
# Gets source bastion release (supported CentOS 8)
echo `cat /etc/centos-release|awk '{print $NF}'` > download/os_release.txt
# Gets kernel version
echo `uname -r` > download/kernel.txt
# Install tar and creates tar.cpio in case of base os where tar is not available
echo -e "\nPrepare TAR package for base OS ..."
dnf download -qy --downloaddir tar-install tar --resolve
ls tar-install/* | cpio -ov > download/tar.cpio
rm -rf tar-install
dnf -qy install tar
# Download all patches (does not apply them on source)
echo -e "Downloading CentOS updates ..."
dnf update -qy --downloadonly --downloaddir centos-updates
tar cf gi-temp/centos-updates-`date +%Y-%m-%d`.tar centos-updates
rm -rf centos-updates
# Download all OS packages required to install OCP, ICS and GI in air-gap env, some of them from epel (python3 always available on CentOS 8)
echo "Downloading additional CentOS packages ..."
dnf -qy install epel-release
packages="ansible haproxy openldap perl podman-docker unzip ipxe-bootimgs skopeo chrony dnsmasq unzip wget jq httpd-tools"
for package in $packages
do
        dnf download -qy --downloaddir centos-packages $package --resolve
done
tar cf gi-temp/centos-packages-`date +%Y-%m-%d`.tar centos-packages
rm -rf centos-packages
# Download some Python libraries (in wheel format) required by gi-runner Ansible playbooks
echo "Downloading python packages for Ansible extensions ..."
packages="passlib dnspython"
for package in $packages
do
        python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
done
tar cf gi-temp/ansible-`date +%Y-%m-%d`.tar ansible
rm -rf ansible
# Setup portable image registry in V2 format
echo "Setup mirror image registry ..."
# - cleanup repository if exists
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
# - Pulls image of portable registry and save it 
podman pull docker.io/library/registry:2
podman save -o gi-temp/oc-registry.tar docker.io/library/registry:2
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
podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:2
# Packs together centos updates, packages, python libraries and portable image
cd gi-temp
tar cf ${local_directory}/download/packages-`date +%Y-%m-%d`.tar centos-updates-* centos-packages-* ansible-* oc-registry.tar
cd $local_directory
rm -rf gi-temp/*
# Download external tools and software (OCP, ICS, matchbox)
echo "Download OCP tools and CoreOS installation files ..."
wget -P gi-temp "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_version}/openshift-client-linux.tar.gz" > /dev/null
wget -P gi-temp "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_version}/openshift-install-linux.tar.gz" > /dev/null
wget -P gi-temp "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/latest/rhcos-live-initramfs.x86_64.img" > /dev/null
wget -P gi-temp "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/latest/rhcos-live-kernel-x86_64" > /dev/null
wget -P gi-temp "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/latest/rhcos-live-rootfs.x86_64.img" > /dev/null
wget -P gi-temp "https://github.com/poseidon/matchbox/releases/download/v0.9.0/matchbox-v0.9.0-linux-amd64.tar.gz" > /dev/null
wget -P gi-temp "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz" > /dev/null
if [ $get_ics == 'Y' ]
then
        wget -P gi-temp "https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz" > /dev/null
fi
cd gi-temp
tar cf ${local_directory}/download/tools.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img opm-linux.tar.gz matchbox-v0.9.0-linux-amd64.tar.gz
if [ $get_ics == 'Y' ]
then
        tar rf ${local_directory}/download/tools.tar cloudctl-linux-amd64.tar.gz
fi
# Install OCP and ICS tools
tar xf openshift-client-linux.tar.gz -C /usr/local/bin
tar xf opm-linux.tar.gz -C /usr/local/bin
if [ $get_ics == 'Y' ]
then
	tar xf cloudctl-linux-amd64.tar.gz -C /usr/local/bin
        mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl
fi
cd $local_directory
rm -rf gi-temp/*
# Mirrors OCP images to portable repository
echo "Mirroring OCP ${ocp_version} images ..."
dnf -qy install jq
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
jq ".auths += $AUTHSTRING" < pull-secret.txt > gi-temp/pull-secret-update.txt
LOCAL_REGISTRY="$host_fqdn:5000"
LOCAL_REPOSITORY=ocp4/openshift4
PRODUCT_REPO='openshift-release-dev'
RELEASE_NAME="ocp-release"
LOCAL_SECRET_JSON='gi-temp/pull-secret-update.txt'
ARCHITECTURE=x86_64
oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${ocp_version}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${ocp_version}-${ARCHITECTURE}
# Mirrors OCP operators
echo "Mirrorring Redhat Operators - ${REDHAT_OPERATORS} ..."
# - Variables defines operators which should be mirrored
REDHAT_OPERATORS="local-storage-operator,ocs-operator"
CERTIFIED_OPERATORS="portworx-certified"
MARKETPLACE_OPERATORS="mongodb-enterprise-rhmp"
COMMUNITY_OPERATORS="portworx-essentials"
# - Mirrroring process
cd gi-temp
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
# - Rename manifest to have constant name
mv manifests-redhat-operator-index-* manifests-redhat-operator-index
mv manifests-certified-operator-index-* manifests-certified-operator-index
mv manifests-redhat-marketplace-index-* manifests-redhat-marketplace-index
mv manifests-community-operator-index-* manifests-community-operator-index
# - Archvining manifests
tar cf ${local_directory}/download/manifests.tar manifests-*
# - Clean up
rm -rf manifests-*
cd $local_directory
# Mirroring Rook-Ceph images (old version for all in one)
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
	podman rmi $image
        rm -rf image.tar
done
# Mirroring ICS images
if [ $get_ics == 'Y' ]
then
        echo "Mirroring ICS ${ics_versions[${ics_version_selected}]}"
	# - install Skopeo utility
        dnf -y install skopeo
	# - declares cases files per ICS release
        declare -a cases=(ibm-cp-common-services-1.1.16.tgz ibm-cp-common-services-1.2.2.tgz ibm-cp-common-services-1.2.3.tgz ibm-cp-common-services-1.3.1.tgz)
	# - declares variables
        CASE_ARCHIVE=${cases[${ics_version_selected}]}
        CASE_INVENTORY_SETUP=ibmCommonServiceOperatorSetup
	# - downloads manifests
        cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/${CASE_ARCHIVE} --outputdir gi-temp/ics_offline
	# - authenticates in external repositories
        sites="cp.icr.io registry.redhat.io registry.access.redhat.com"
        for site in $sites
        do
                echo $site
                cloudctl case launch --case ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry $site --user $rh_account --pass $rh_account_pwd"
        done
        cloudctl case launch --case ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry `hostname --long`:5000 --user admin --pass guardium"
	# - mirrors ICS images
        cloudctl case launch --case ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action mirror-images --args "--registry `hostname --long`:5000 --inputDir ics_offline"
	# - archives ICS manifests
	cd gi-temp
        tar cf ${local_directory}/download/ics_offline-${ics_version}.tar ics_offline
	# - clean up
	cd $local_directory
        rm -rf gi-temp/*
fi
# Archives mirrored images
echo "Archiving mirrored registry ..."
podman stop bastion-registry
cd /opt/registry
tar cf ${local_directory}/download/ocp-registry-with-olm-${ocp_version}.tar data
cd $local_directory
# Making target tar (split in 10GB pieces)
cd download
now_is=`date +%Y-%m-%d`
if [ $get_ics == 'Y' ]
then
	ics_info="ics-release-${ics_version}"
else
	ics_info="no-ics"
fi
tar czpvf - *.tar *.txt | split -d -b 10G - air-gap-files-centos-`cat /etc/centos-release|awk '{print $NF}'`-ocp-release-${ocp_version}-${ics_info}-os-packages-sync-${now_is}.tar
rm -f *.tar *.txt
cd $local_directory
# Cleanup gi-temp, portable-registry
rm -f ${local_directory}/pull-secret.txt
rm -rf gi-temp
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry
echo "AIR GAPPED FILE(S) PREPARED - copy them from download directory to air-gapped bastion machine"
