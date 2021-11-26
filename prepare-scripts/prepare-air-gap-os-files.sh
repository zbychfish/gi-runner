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
echo `cat /etc/system-release|sed -e "s/ /_/g"` > $temp_dir/os_release.txt
# Gets kernel version
echo `uname -r` > $temp_dir/kernel.txt
# Install all required software
echo -e "Downloading OS updates ..."
cd $temp_dir
dnf update -qy --downloadonly --downloaddir os-updates
check_exit_code $? "Cannot download update packages" 
echo "Update system ..."
cd os-updates
dnf -qy localinstall * --allowerasing
check_exit_code $? "Cannot update system"
cd ..
# Download all OS packages required to install OCP, ICS and GI in air-gap env, some of them from epel (python3 always available on CentOS 8)
echo "Downloading additional OS packages ..."
packages="ansible haproxy openldap perl podman-docker ipxe-bootimgs skopeo chrony dnsmasq unzip wget jq httpd-tools podman python3 python3-ldap openldap-servers openldap-clients vim"
for package in $packages
do
        dnf download -qy --downloaddir os-packages $package --resolve
	check_exit_code $? "Cannot download $package package" 
	echo "Downloaded: $package"
done
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
	echo "Downloaded: $package"
done
wget -P galaxy https://galaxy.ansible.com/download/community-general-3.3.2.tar.gz
check_exit_code $? "Cannot download Ansible Galaxy packages" 
tar cf $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar os-updates os-packages ansible galaxy os_release.txt kernel.txt
cd $local_directory
rm -rf $temp_dir
# Downloads gi-runner archive
wget -P $air_dir https://github.com/zbychfish/gi-runner/archive/refs/heads/main.zip
check_exit_code $? "Cannot download gi-runner package" 
mv $air_dir/main.zip $air_dir/gi-runner.zip
echo "OS files - copy $air_dir/gi-runner.zip and $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar to the air-gapped bastion machine"
