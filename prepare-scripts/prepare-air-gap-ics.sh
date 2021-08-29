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

echo "Setting environment"
local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates target download directory
mkdir -p $temp_dir
# Creates temporary directory
mkdir -p $air_dir
read -p "Insert RH account name: " rh_account
read -sp "Insert RH account password: " rh_account_pwd
declare -a ics_versions=(3.7.1 3.7.2 3.7.4 3.8.1 3.9.0 3.9.1 3.10.0)
declare -a cases=(ibm-cp-common-services-1.3.1.tgz ibm-cp-common-services-1.3.2.tgz ibm-cp-common-services-1.3.4.tgz ibm-cp-common-services-1.4.1.tgz ibm-cp-common-services-1.5.0.tgz ibm-cp-common-services-1.5.1.tgz ibm-cp-common-services-1.6.0.tgz)
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
# Gets source bastion release (supported CentOS 8)
dnf -qy install python3 podman wget
check_exit_code $? "Cannot download image registry"
# - cleanup repository if exists
echo "Installing local image registry ..."
podman stop bastion-registry
podman container prune <<< 'Y'
rm -rf /opt/registry
# - Pulls image of portable registry and save it 
podman pull docker.io/library/registry:2.6
check_exit_code $? "Cannot download image registry image"
# - Prepares portable registry directory structure
mkdir -p /opt/registry/{auth,certs,data}
# - Creates SSL cert for portable registry (only for mirroring, new one will be created in disconnected env)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/bastion.repo.pem -x509 -days 365 -out /opt/registry/certs/bastion.repo.crt -subj "/C=PL/ST=Miedzyrzecz/L=/O=Test /OU=Test/CN=`hostname --long`" -addext "subjectAltName = DNS:`hostname --long`"
check_exit_code $? "Cannot create SSl certificate"
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
podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:2.6
check_exit_code $? "Cannot start temporary image registry"
# Packs together centos updates, packages, python libraries and portable image
cd $air_dir
declare -a ocp_files=("https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz")
for file in ${ocp_files[@]}
do
        wget $file > /dev/null
        check_exit_code $? "Cannot donwload $file"
done
tar xf cloudctl-linux-amd64.tar.gz -C /usr/local/bin
tar xf openshift-client-linux.tar.gz -C /usr/local/bin
rm -f openshift-client-linux.tar.gz
mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl
echo "Mirroring ICS ${ics_versions[${ics_version_selected}]}"
# Mirrors OCP images to portable repository
dnf -qy install jq
check_exit_code $? "Cannot install jq package"
dnf -qy install skopeo
check_exit_code $? "Cannot install skopeo package"
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
# Mirroring ICS images
# - install Skopeo utility
# - declares cases files per ICS release
# - declares variables
CASE_ARCHIVE=${cases[${ics_version_selected}]}
CASE_INVENTORY_SETUP=ibmCommonServiceOperatorSetup
# - downloads manifests
cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/${CASE_ARCHIVE} --outputdir $temp_dir/ics_offline
check_exit_code $? "Cannot download ICS case file"
# - authenticates in external repositories
sites="cp.icr.io registry.redhat.io registry.access.redhat.com"
for site in $sites
do
	echo $site
        cloudctl case launch --case $temp_dir/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry $site --user $rh_account --pass $rh_account_pwd"
	check_exit_code $? "Cannot configure credentials for site $site"
done
cloudctl case launch --case $temp_dir/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action configure-creds-airgap --args "--registry `hostname --long`:5000 --user admin --pass guardium"
# - mirrors ICS images
cloudctl case launch --case $temp_dir/ics_offline/${CASE_ARCHIVE} --inventory ${CASE_INVENTORY_SETUP} --action mirror-images --args "--registry `hostname --long`:5000 --inputDir $temp_dir/ics_offline"
check_exit_code $? "Cannot mirror ICS images"
# - archives ICS manifests
cd $temp_dir
tar cf $air_dir/ics_offline.tar ics_offline
rm -rf ics_offline
podman stop bastion-registry
cd /opt/registry
tar cf ${air_dir}/ics_images.tar data
cd $air_dir
#tar czpvf - *.tar | split -d -b 10G - ics_registry-${ics_version}.tar
tar cf ics_registry-${ics_versions[${ics_version_selected}]}.tar ics_images.tar ics_offline.tar cloudctl-linux-amd64.tar.gz
rm -f ics_offline.tar cloudctl-linux-amd64.tar.gz ics_images.tar
cd $local_directory
# Cleanup gi-temp, portable-registry
podman rm bastion-registry
podman rmi --all
rm -rf /opt/registry
rm -rf $temp_dir
echo "ICS ${ics_versions[${ics_version_selected}]} files prepared - copy $air_dir/ics_registry-${ics_versions[${ics_version_selected}]}.tar to air-gapped bastion machine"
