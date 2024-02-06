#!/bin/bash

#author: zibi - zszmigiero@gmail.com
script_argument=$1
! [ -f ./init.sh ] && { printf "This script must be executed from gi-runner home directoryi\n"; exit 1; }
# load functions
. ./funcs/functions.sh
# import global variables
. ./funcs/init.globals.sh
ansible_constants # synchronizes constants between shell and ansible
trap "display_error 'Unexpected error'" EXIT
export MPID=$$ #init.sh process ID
#MAIN PART
mkdir -p $GI_TEMP
echo "#gi-runner configuration file" > $variables_file
save_variable IBMPAK_HOME ${GI_HOME}
msg "gi-runner installation tool for IBM Security Cloud Pak's on bare metal" title
msg "Checking OS release" task
save_variable KUBECONFIG "$GI_HOME/ocp/auth/kubeconfig"
check_linux_distribution_and_release
msg "Deployment decisions with/without Internet Access" task
get_network_installation_type
msg "Deployment decisions about the software and its releases" task
get_software_selection
get_software_architecture
get_ocp_domain
[[ "$use_air_gap" == 'N' && "$use_proxy" == 'P' ]] && configure_os_for_proxy || unset_proxy_settings
[[ "$use_air_gap" == 'Y' ]] && prepare_offline_bastion || software_installation_on_online
msg "Installing tools for init.sh" task
[[ "$use_air_gap" == 'N' ]] && { dnf -qy install jq;[[ $? -ne 0 ]] && display_error "Cannot install jq"; }
get_network_architecture
#[[ $one_subnet == 'N' ]] && get_subnets
get_bastion_info
msg "Collecting data about bootstrap node (IP and MAC addres, name)" task
get_nodes_info 1 "boot"
msg "Collecting Control Plane nodes data (IP and MAC addres, name), values must be inserted as comma separated list without spaces" task
get_nodes_info 3 "mst"
get_worker_nodes
get_set_services
get_hardware_info
get_service_assignment
get_cluster_storage_info
get_inter_cluster_info
get_credentials
get_certificates
[[ "$gi_install" == 'Y' ]] && get_gi_options
[[ "$ics_install" == 'Y' || "$gi_install" == 'Y' ]] && get_ics_options
[[ "$cp4s_install" == 'Y' ]] && get_cp4s_options
[[ "$install_ldap" == 'Y' ]] && get_ldap_options
create_cluster_ssh_key
msg "All information to deploy environment collected" info
if LAST_KERNEL=$(rpm -q --last kernel | awk 'NR==1{sub(/kernel-/,""); print $1}'); CURRENT_KERNEL=$(uname -r); if [ $LAST_KERNEL != $CURRENT_KERNEL ]; then true; else false; fi;
then
	msg "System reboot required because new kernel has been installed" info
	msg "Execute these commands after relogin to bastion:" info
	[[ $use_proxy == 'P' ]] &&  msg "- import PROXY settings: \". /etc/profile\"" info
	msg "- go to gi-runner home directory: \"cd $GI_HOME\"" info
	msg "- import variables: \". $variables_file\"" info
        msg "- start first playbook: \"ansible-playbook play/install.yaml\"" info
	read -p "Press enter to continue to reboot system"
	shutdown -r now
else
	msg "Execute commands below to continue:" info
	[[ $use_proxy == 'P' ]] &&  msg "- import PROXY settings: \". /etc/profile\"" info
	msg "- import variables: \". $variables_file\"" info
	msg "- start playbook: \"ansible-playbook plays/install.yaml\"" info
fi
trap - EXIT
