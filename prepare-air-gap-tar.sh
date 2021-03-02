#!/bin/bash

read -p "Insert RedHat pull secret: " pull_secret
echo "$pull_secret" > "pull-secret.txt"
read -p "Insert your mail address to authenticate in RedHat Network: " mail
read -p "Insert OCP version to mirror (for example 4.6.19): " version
dnf update -qy --downloadonly --downloaddir centos-updates
tar cf centos-updates-`date +%Y-%m-%d`.tar centos-updates
rm -rf centos-updates
packages="git haproxy openldap perl podman-docker unzip ipxe-bootimgs httpd"
for package in $packages
do
	dnf download -qy --downloaddir centos-packages $package --resolve
done
tar cf centos-packages-`date +%Y-%m-%d`.tar centos-packages 
rm -rf centos-packages
packages="passlib dnspython"
for package in $packages
do
	python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
done
tar cf ansible-`date +%Y-%m-%d`.tar ansible
rm -rf ansible
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
podman stop bastion-registry
podman container prune
podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/bastion.repo.htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:2
semanage permissive -a NetworkManager_t
host_fqdn=$( hostname --long )
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5000\": {\"auth\": \"$b64auth\",\"email\": \"$mail\"}}"
jq ".auths += $AUTHSTRING" < pull-secret.txt > pull-secret-update.txt
LOCAL_REGISTRY="$host_fqdn:5000"
LOCAL_REPOSITORY=ocp4/openshift4
PRODUCT_REPO='openshift-release-dev'
RELEASE_NAME="ocp-release"
LOCAL_SECRET_JSON='/root/gi-runner/pull-secret-update.txt'
ARCHITECTURE=x86_64
oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${version}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${version}-${ARCHITECTURE}
exit 0
tar cf air-gap.tar *.tar
rm -rf centos-updates-* centos-packages-* ansible-* oc-registry.tar
mv air-gap.tar download

