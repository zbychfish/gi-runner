#!/bin/bash

local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates target download directory
mkdir -p $air_dir
# Creates temporary directory
mkdir -p $temp_dir
# Gets list of parameters 
read -p "Insert OCP release to mirror images: " ocp_release
ocp_major_release=`echo $ocp_release|cut -f -2 -d .`
read -p "Insert RedHat pull secret: " pull_secret
echo "$pull_secret" > $temp_dir/pull-secret.txt
read -p "Insert your mail address to authenticate in RedHat Network: " mail
echo -e "\n"
# Setup portable registry
echo "Setup mirror image registry ..."
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
# - Pulls image of portable registry and save it 
podman pull docker.io/library/registry:2
podman save -o $air_dir/oc-registry.tar docker.io/library/registry:2
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
cd $temp_dir
rm -f openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img matchbox-v0.9.0-linux-amd64.tar.gz opm-linux.tar.gz
# Download external tools and software (OCP, ICS, matchbox)
echo "Download OCP tools and CoreOS installation files ..."
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-client-linux.tar.gz" > /dev/null
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-install-linux.tar.gz" > /dev/null
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-initramfs.x86_64.img" > /dev/null
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-kernel-x86_64" > /dev/null
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-rootfs.x86_64.img" > /dev/null
wget "https://github.com/poseidon/matchbox/releases/download/v0.9.0/matchbox-v0.9.0-linux-amd64.tar.gz" > /dev/null
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz" > /dev/null
tar cf $air_dir/tools.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img opm-linux.tar.gz matchbox-v0.9.0-linux-amd64.tar.gz
# Install OCP tools
tar xf openshift-client-linux.tar.gz -C /usr/local/bin
tar xf opm-linux.tar.gz -C /usr/local/bin
# Mirrors OCP images to portable repository
echo "Mirroring OCP ${ocp_version} images ..."
dnf -qy install jq
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
jq ".auths += $AUTHSTRING" < $temp_dir/pull-secret.txt > $temp_dir/pull-secret-update.txt
LOCAL_REGISTRY="$host_fqdn:5000"
LOCAL_REPOSITORY=ocp4/openshift4
PRODUCT_REPO='openshift-release-dev'
RELEASE_NAME="ocp-release"
LOCAL_SECRET_JSON=$temp_dir/pull-secret-update.txt
ARCHITECTURE=x86_64
oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${ocp_release}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${ocp_release}-${ARCHITECTURE}
# Mirrors OCP operators
podman stop bastion-registry
cd /opt/registry
tar cf $air_dir/coreos-registry.tar data
cd $air_dir
tar cf coreos-registry-${ocp_version}.tar tools.tar oc-registry.tar coreos-registry.tar
rm tools.tar oc-registry.tar coreos-registry.tar
rm -rf $temp_dir
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry
echo "CoreOS images prepared - copy file ${air_dir}/coreos-registry-${ocp_version}.tar to air-gapped bastion machine"
