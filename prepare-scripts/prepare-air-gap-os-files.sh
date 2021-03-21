#!/bin/bash

local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates target download directory
mkdir -p $air_dir
# Creates temporary directory
mkdir -p $temp_dir
# Gets source bastion release (supported CentOS 8)
echo `cat /etc/centos-release|awk '{print $NF}'` > $air_dir/os_release.txt
# Gets kernel version
echo `uname -r` > $air_dir/kernel.txt
# Install tar and creates tar.cpio in case of base os where tar is not available
echo -e "\nPrepare TAR and UNZIP package for base OS ..."
cd $temp_dir
dnf download -qy --downloaddir . tar --resolve
dnf download -qy --downloaddir . unzip --resolve
tar cf $air_dir/tar.cpio *rpm
rm -f *rpm
dnf -qy install tar
# Install all required software
echo -e "Downloading CentOS updates ..."
dnf update -qy --downloadonly --downloaddir centos-updates
tar cf $air_dir/centos-updates-`date +%Y-%m-%d`.tar centos-updates
rm -rf centos-updates
echo "Update system ..."
dnf -qy update
# Download all OS packages required to install OCP, ICS and GI in air-gap env, some of them from epel (python3 always available on CentOS 8)
echo "Downloading additional CentOS packages ..."
packages="ansible haproxy openldap perl podman-docker ipxe-bootimgs skopeo chrony dnsmasq unzip wget jq httpd-tools podman python3"
dnf -qy install epel-release
for package in $packages
do
        dnf download -qy --downloaddir centos-packages $package --resolve
done
tar cf $air_dir/centos-packages-`date +%Y-%m-%d`.tar centos-packages
rm -rf centos-packages
# Install packages
echo "Installing missing packages ..."
dnf -qy install python3 podman wget
# Download some Python libraries (in wheel format) required by gi-runner Ansible playbooks
echo "Downloading python packages for Ansible extensions ..."
packages="passlib dnspython"
for package in $packages
do
        python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
done
tar cf $air_dir/ansible-`date +%Y-%m-%d`.tar ansible
rm -rf ansible
cd $air_dir
tar cf $temp_dir/os-`cat /etc/centos-release|awk '{print $1"-"$2"-"$3"-"$NF}'`-`date +%Y-%m-%d`.tar *
rm -f *
mv $temp_dir/os*tar .
cd $local_directory
rm -rf $temp_dir
echo "OS files - copy $air_dir/os-`cat /etc/centos-release|awk '{print $1"-"$2"-"$3"-"$NF}'`-`date +%Y-%m-%d`.tar to the air-gap bastion machine"
