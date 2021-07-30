#!/bin/bash

function check_exit_code() {
        if [[ $1 -ne 0 ]]
        then
		echo $2
		echo "Please check the reason of problem and set machine to initial state - this script must be run in exactly this same state as air-gapped bastion"
		exit 1
	else
		echo "OK"
	fi
}

local_directory=`pwd`
host_fqdn=$( hostname --long )
temp_dir=$local_directory/gi-temp
air_dir=$local_directory/air-gap
# Creates target download directory
mkdir -p $air_dir
# Creates temporary directory
mkdir -p $temp_dir
# Gets source bastion release (supported Fedora)
echo `cat /etc/system-release|sed -e "s/ /_/g"` > $air_dir/os_release.txt
# Gets kernel version
echo `uname -r` > $air_dir/kernel.txt
# Install tar and creates tar.cpio in case of base os where tar is not available
echo -e "\nPrepare TAR and UNZIP package for base OS ..."
cd $temp_dir
dnf download -qy --downloaddir . tar --resolve
check_exit_code $? "Cannot download TAR package" 
# - archives ICS manifests
dnf download -qy --downloaddir . unzip --resolve
check_exit_code $? "Cannot download UNZIP package" 
tar cf $air_dir/tar.cpio *rpm
rm -f *rpm
dnf -qy install tar
# Install all required software
echo -e "Downloading OS updates ..."
dnf update -qy --downloadonly --downloaddir os-updates
check_exit_code $? "Cannot download update packages" 
tar cf $air_dir/os-updates-`date +%Y-%m-%d`.tar os-updates
rm -rf os-updates
echo "Update system ..."
dnf -qy update
check_exit_code $? "Cannot update system" 
# Download all OS packages required to install OCP, ICS and GI in air-gap env, some of them from epel (python3 always available on CentOS 8)
echo "Downloading additional OS packages ..."
packages="ansible haproxy openldap perl podman-docker ipxe-bootimgs skopeo chrony dnsmasq unzip wget jq httpd-tools podman python3 python3-ldap openldap-servers openldap-clients"
#dnf -qy install epel-release
for package in $packages
do
        dnf download -qy --downloaddir os-packages $package --resolve
	check_exit_code $? "Cannot download $package package" 
done
tar cf $air_dir/os-packages-`date +%Y-%m-%d`.tar os-packages
rm -rf os-packages
# Install packages
echo "Installing missing packages ..."
dnf -qy install python3 podman wget
check_exit_code $? "Cannot install some packages" 
# Download some Python libraries (in wheel format) required by gi-runner Ansible playbooks
echo "Downloading python packages for Ansible extensions ..."
packages="passlib dnspython"
for package in $packages
do
        python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
	check_exit_code $? "Cannot download Ansible extension $package" 
done
tar cf $air_dir/ansible-`date +%Y-%m-%d`.tar ansible
rm -rf ansible
wget -P galaxy https://galaxy.ansible.com/download/community-general-3.3.2.tar.gz
check_exit_code $? "Cannot download Ansible Galaxy packages" 
tar cf $air_dir/galaxy-`date +%Y-%m-%d`.tar galaxy
rm -rf galaxy
cd $air_dir
tar cf $temp_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar *
rm -f *
mv $temp_dir/os*tar .
cd $local_directory
rm -rf $temp_dir
echo "OS files - copy $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar to the air-gap bastion machine"
