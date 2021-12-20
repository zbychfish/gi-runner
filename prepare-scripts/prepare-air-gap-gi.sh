#!/bin/bash

function check_exit_code() {
        if [[ $1 -ne 0 ]]
        then
                echo $2
                echo "Please check the reason of problem, you can continue image mirroring using 'repeat' argument"
                exit 1
        else
                echo "OK"
        fi
}

echo "Setting environment"
if [[ $# -ne 0 && $1 != "repeat" ]]
then
	echo "To restart mirroring process use paramater 'repeat'"
	exit 1
fi
registry_version=2.7.1
local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates target download directory
if [ $# -eq 0 ]
then
	echo "Cleanup temp directory $temp_dir"
	rm -rf $temp_dir
	mkdir -p $temp_dir
	# Creates temporary directory
	mkdir -p $air_dir
fi
read -sp "Insert your IBM Cloud Key: " ibm_account_key
declare -a gi_versions=(3.0.0 3.0.1 3.0.2 3.1.0)
declare -a cases=(ibm-guardium-insights-2.0.0.tgz ibm-guardium-insights-2.0.1.tgz ibm-guardium-insights-2.0.2.tgz ibm-guardium-insights-2.1.0.tgz)
while [[ ( -z $gi_version_selected ) || ( $gi_version_selected -lt 1 || $gi_version_selected -gt $i ) ]]
do
	echo "Select GI version to mirror:"
        i=1
        for gi_version in "${gi_versions[@]}"
        do
        	echo "$i - $gi_version"
                i=$((i+1))
        done
        read -p "Your choice?: " gi_version_selected
done
gi_version_selected=$(($gi_version_selected-1))
if [ $# -eq 0 ]
then
	# Gets source bastion release (supported CentOS 8)
	dnf -qy install python3 podman wget
	check_exit_code $? "Cannot download OS packages"
	echo "Installing local image registry ..."
	# - cleanup repository if exists
	podman stop bastion-registry
	podman container prune <<< 'Y'
	rm -rf /opt/registry
	# - Pulls image of portable registry and save it 
	podman pull docker.io/library/registry:${registry_version}
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
	podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:${registry_version}
	check_exit_code $? "Cannot start temporary image registry"
	# Packs together centos updates, packages, python libraries and portable image
	cd $temp_dir
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
	# Mirrors GI images to portable repository
	dnf -qy install jq
	check_exit_code $? "Cannot install jq package"
	dnf -qy install skopeo
	check_exit_code $? "Cannot install skopeo package"
fi
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
# Mirroring GI images
echo "Mirroring GI ${gi_versions[${gi_version_selected}]}"
# - declares variables
CASE_ARCHIVE=${cases[${gi_version_selected}]}
CASE_INVENTORY_SETUP=install
# - downloads manifests
if [ $# -eq 0 ]
then
	cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/${CASE_ARCHIVE} --outputdir $temp_dir/gi_offline
	check_exit_code $? "Cannot download GI case file"
	# - authenticates in external repositories
	sites="cp.icr.io"
	for site in $sites
	do
		echo $site
	        cloudctl case launch --case $temp_dir/gi_offline/${CASE_ARCHIVE} --action configure-creds-airgap --inventory $CASE_INVENTORY_SETUP --args "--registry $site --user cp --pass $ibm_account_key"
		check_exit_code $? "Cannot configure credentials for site $site"
	done
	cloudctl case launch --case $temp_dir/gi_offline/${CASE_ARCHIVE} --action configure-creds-airgap --inventory $CASE_INVENTORY_SETUP --args "--registry `hostname --long`:5000 --user admin --pass guardium"
fi
# - mirrors GI images
cloudctl case launch --case $temp_dir/gi_offline/${CASE_ARCHIVE} --action mirror-images --inventory $CASE_INVENTORY_SETUP --args "--registry `hostname --long`:5000 --inputDir $temp_dir/gi_offline"
mirror_status=$?
# - archives GI manifests
echo "Mirroring status: $mirror_status"
if [ $mirror_status -ne 0 ]
then
	echo "Mirroring process failed, restart script with parameter repeat to finish"
	exit 1
fi
podman stop bastion-registry
tar cf ${air_dir}/gi_registry-${gi_versions[${gi_version_selected}]}.tar gi_offline cloudctl-linux-amd64.tar.gz
cd /opt/registry
tar -rf ${air_dir}/gi_registry-${gi_versions[${gi_version_selected}]}.tar data
cd $temp_dir
rm -rf /opt/registry
cd $local_directory
# Cleanup gi-temp, portable-registry
podman rm bastion-registry
podman rmi --all
#rm -rf $temp_dir
echo "GI ${gi_versions[${gi_version_selected}]} files prepared - copy $air_dir/gi_registry-${gi_versions[${gi_version_selected}]}.tar to air-gapped bastion machine"
