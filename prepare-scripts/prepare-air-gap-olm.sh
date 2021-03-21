#!/bin/bash

local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates target download directory
mkdir -p $air_dir
# Creates temporary directory
mkdir -p $temp_dir
# Gets list of parameters to create repo
read -p "Insert OCP version to mirror (for example 4.6.19): " ocp_version
read -p "Insert RedHat pull secret: " pull_secret
echo "$pull_secret" > $temp_dir/pull-secret.txt
read -p "Insert RH account name: " rh_account
read -sp "Insert RH account password: " rh_account_pwd
echo -e "\n"
# - cleanup repository if exists
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
# - Pulls image of portable registry and save it
podman pull docker.io/library/registry:2
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
# Get tools
cd $temp_dir
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz" > /dev/null
wget "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_version}/openshift-client-linux.tar.gz" > /dev/null
# Install OCP and ICS tools
tar xf openshift-client-linux.tar.gz -C /usr/local/bin
tar xf opm-linux.tar.gz -C /usr/local/bin
rm -f openshift-client-linux.tar.gz opm-linux.tar.gz
dnf -qy install jq
LOCAL_REGISTRY="$host_fqdn:5000"
REDHAT_OPERATORS="local-storage-operator,ocs-operator"
CERTIFIED_OPERATORS="portworx-certified"
MARKETPLACE_OPERATORS="mongodb-enterprise-rhmp"
COMMUNITY_OPERATORS="portworx-essentials"
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
jq ".auths += $AUTHSTRING" < $temp_dir/pull-secret.txt > $temp_dir/pull-secret-update.txt
LOCAL_REGISTRY="$host_fqdn:5000"
echo $REDHAT_OPERATORS > $air_dir/operators.txt
echo $CERTIFIED_OPERATORS >> $air_dir/operators.txt
echo $MARKETPLACE_OPERATORS >> $air_dir/operators.txt
echo $COMMUNITY_OPERATORS >> $air_dir/operators.txt
# - Mirrroring process
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
tar cf $air_dir/manifests.tar manifests-*
# - Clean up
rm -rf manifests-*
podman stop bastion-registry
cd /opt/registry
tar cf $air_dir/olm-registry.tar data
cd $air_dir
ocp_major_release=`echo $ocp_version|awk -F'.' '{print $1"."$2}'`
tar cf olm-registry-${ocp_major_version}-`date +%Y-%m-%d`.tar olm-registry.tar manifests.tar operators.txt
rm -f olm-registry.tar manifests.tar operators.txt
rm -rf $temp_dir
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry
echo "OLM images prepared for ${ocp_major_version} - copy $air_dir/olm-registry-${ocp_major_version}-`date +%Y-%m-%d`.tarto air-gapped bastion machine"

