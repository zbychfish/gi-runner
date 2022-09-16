#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/shared_functions.sh

get_pre_scripts_variables
pre_scripts_init_no_jq
check_linux_distribution_and_release

msg "Gathering OS release and kernel version" true
echo `cat /etc/system-release|sed -e "s/ /_/g"` > $GI_TEMP/os_release.txt
echo `uname -r` > $GI_TEMP/kernel.txt
msg "Downloading OS updates ..." true
cd $GI_TEMP
dnf update -qy --downloadonly --downloaddir os-updates
test $(check_exit_code $?) || (msg "Cannot download update packages" true; exit 1)
msg "Update system ..." true
cd os-updates
dnf -qy localinstall * --allowerasing
test $(check_exit_code $?) || (msg "Cannot update system" true; exit 1)
cd ..
msg "Downloading additional OS packages ..." true
packages="ansible haproxy openldap perl podman-docker ipxe-bootimgs skopeo chrony dnsmasq unzip wget jq httpd-tools podman python3 python3-ldap openldap-servers openldap-clients vim python3-pip"
for package in $packages
do
        dnf download -qy --downloaddir os-packages $package --resolve
	test $(check_exit_code $?) || (msg "Cannot download $package package" true; exit 1)
	msg "Downloaded: $package" true
done
msg "Installing missing packages ..." true
dnf -qy install python3 podman wget python3-pip
test $(check_exit_code $?) || (msg "Cannot install support tools" true; exit 1)
msg "Downloading python packages for Ansible extensions ..." true
packages="passlib dnspython beautifulsoup4 argparse jmespath"
for package in $packages
do
        python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
	test $(check_exit_code $?) || (msg "Cannot download Python module - $package" true; exit 1)
	msg "Downloaded: $package" true
done
galaxy_packages="community-general-${galaxy_community_general} ansible-utils-${galaxy_ansible_utils} community-crypto-${galaxy_community_crypto} containers-podman-${galaxy_containers_podman}"
for galaxy_package in $galaxy_packages
do
	wget -P galaxy https://galaxy.ansible.com/download/${galaxy_package}.tar.gz
	test $(check_exit_code $?) || (msg "Cannot download Ansible galaxy package ${galaxy_package}" true; exit 1)
done
tar cf $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar os-updates os-packages ansible galaxy os_release.txt kernel.txt
cd $GI_HOME
rm -rf $GI_TEMP
wget -P $air_dir https://github.com/zbychfish/gi-runner/archive/refs/heads/main.zip
test $(check_exit_code $?) || (msg "Cannot download gi-runner archive from github" true; exit 1)
mv $air_dir/main.zip $air_dir/gi-runner.zip
msg "OS files - copy $air_dir/gi-runner.zip and $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar to the air-gapped bastion machine" true
