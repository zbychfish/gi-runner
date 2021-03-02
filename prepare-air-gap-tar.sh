#!/bin/bash

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
packages="ansible passlib dnspython"
for package in $packages
do
	python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
done
tar cf ansible-`date +%Y-%m-%d`.tar ansible
rm -rf ansible
podman pull docker.io/library/registry:2
podman save -o oc-registry.tar docker.io/library/registry:2
tar cf air-gap.tar *.tar
rm -rf centos-updates-* centos-packages-* ansible-* oc-registry.tar
mv air-gap.tar download

