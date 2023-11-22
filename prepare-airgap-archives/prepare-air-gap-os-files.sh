#!/bin/bash
set -e
trap "exit 1" ERR

source scripts/init.globals.sh
source scripts/functions.sh

get_pre_scripts_variables
pre_scripts_init_no_jq
check_linux_distribution_and_release

msg "Gathering OS release and kernel version" task
echo `cat /etc/system-release|sed -e "s/ /_/g"` > $GI_TEMP/os_release.txt
echo `uname -r` > $GI_TEMP/kernel.txt
msg "Downloading OS updates ..." task
cd $GI_TEMP
dnf update -qy --downloadonly --downloaddir os-updates
test $(check_exit_code $?) || (msg "Cannot download update packages" info; exit 1)
msg "Update system ..." task
cd os-updates
dnf -qy localinstall * --allowerasing
test $(check_exit_code $?) || (msg "Cannot update system" info; exit 1)
cd ..
msg "Downloading additional OS packages ..." task
for package in $linux_soft
do
        dnf download -qy --downloaddir os-packages $package --resolve
	test $(check_exit_code $?) || (msg "Cannot download $package package" info; exit 1)
	msg "Downloaded: $package" info
done
msg "Installing missing packages ..." task
dnf -qy install python3 podman wget python3-pip
test $(check_exit_code $?) || (msg "Cannot install support tools" info; exit 1)
msg "Downloading python packages for Ansible extensions ..." task
for package in $python_soft
do
        python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
	test $(check_exit_code $?) || (msg "Cannot download Python module - $package" info; exit 1)
	msg "Downloaded: $package" info
done
msg "Downloading Ansible Galaxy extensions ..." task
for galaxy_package in $galaxy_soft
do
	wget -P galaxy https://galaxy.ansible.com/download/${galaxy_package}.tar.gz
	test $(check_exit_code $?) || (msg "Cannot download Ansible galaxy package ${galaxy_package}" info; exit 1)
	msg "Downloaded: $galaxy_package" info
done
tar cf $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar os-updates os-packages ansible galaxy os_release.txt kernel.txt
cd $GI_HOME
rm -rf $GI_TEMP
wget -P $air_dir https://github.com/zbychfish/gi-runner/archive/refs/heads/main.zip
test $(check_exit_code $?) || (msg "Cannot download gi-runner archive from github" info; exit 1)
mv $air_dir/main.zip $air_dir/gi-runner.zip
msg "OS files - copy $air_dir/gi-runner.zip and $air_dir/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar to the air-gapped bastion machine" info
