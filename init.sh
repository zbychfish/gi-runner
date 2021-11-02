#!/bin/bash

GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
mkdir -p $GI_TEMP
file=variables.sh
declare -a gi_versions=(3.0.0 3.0.1 3.0.2)
declare -a ics_versions=(3.7.4 3.8.1 3.9.1 3.10.0 3.11.0 3.12.0)
declare -a bundled_in_gi_ics_versions=(0 2 3)
declare -a ocp_major_versions=(4.6 4.7 4.8 4.9)
declare -a ocp_supported_by_gi=(0 0:1 0:1:2)
declare -a ocp_supported_by_ics=(0:1 0:1 0:1:2 0:1:2 0:1:2 0:1:2:3)

echo "# Guardium Insights installation parameters" > $file
# Get information about environment type (Air-Gapped, Proxy, Direct access to the internet)
echo "*** Air-Gapped Setup ***"
while ! [[ $use_air_gap == 'Y' || $use_air_gap == 'N' ]] # While string is different or empty...
do
        printf "Is your environment air-gapped? (\e[4mN\e[0m)o/(Y)es: "
        read use_air_gap
        use_air_gap=${use_air_gap:-N}
        if ! [[ $use_air_gap == 'Y' || $use_air_gap == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
if [ $use_air_gap == 'Y' ]
then
        echo "export GI_INTERNET_ACCESS=A" >> $file
fi
if [[ $use_air_gap == 'N' ]]
then
        echo "*** Proxy Setup ***"
        while ! [[ $use_proxy == 'D' || $use_proxy == 'P' ]] # While string is different or empty...
        do
                printf "Has your environment direct access to the internet or use HTTP proxy? (\e[4mD\e[0m)irect/(P)roxy: "
                read use_proxy
                use_proxy=${use_proxy:-D}
                if ! [[ $use_proxy == 'D' || $use_proxy == 'P' ]]
                then
                        echo "Incorrect value"
                fi
        done
        echo export GI_INTERNET_ACCESS=${use_proxy} >> $file
fi
# GI installation
while ! [[ $gi_install == 'Y' || $gi_install == 'N' ]] # While string is different or empty...
do
        printf "Would you like to install Guardium Insights in this process? (\e[4mN\e[0m)o/(Y)es: "
        read gi_install
        gi_install=${gi_install:-N}
        if ! [[ $gi_install == 'Y' || $gi_install == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
echo "export GI_INSTALL_GI=$gi_install" >> $file
if [[ $gi_install == 'Y' ]]
then
        while [[ $gi_version_selected == '' ]]
        do
                echo "Select GI version:"
                i=1
                for gi_version in "${gi_versions[@]}"
                do
                        echo "$i - $gi_version"
                        i=$((i+1))
                done
                read -p "Your choice?: " gi_version_selected
        	gi_version_selected=$(($gi_version_selected-1))
		(for e in "${gi_versions[@]}"; do [[ "$e" == "${gi_versions[$gi_version_selected]}" ]] && exit 0; done) && is_correct_selection=0 || is_correct_selection=1
	        if [[ $is_correct_selection -ne 0 || $gi_version_selected -lt 0 ]]
        	then
                	gi_version_selected=''
	                echo "Incorrect choice"
        	fi
        done
	echo "Guardium Insights installation choice assumes installation of bundled version of ICS"
	echo "- ICS 3.7.4 for GI 3.0.0"
	echo "- ICS 3.9.0 for GI 3.0.1"
	echo "- ICS 3.10.0 for GI 3.0.2"
	echo "If you would like install different ICS version (supported by selected GI) please modify variable.sh file before starting playbooks"
	echo "In case of air-gapped installation you must install the bundled ICS version"
	echo "export GI_VERSION=$gi_version_selected" >> $file
	ics_version_selected=${bundled_in_gi_ics_versions[$gi_version_selected]}
	ics_install='Y'
        echo "export GI_ICS_VERSION=$ics_version_selected" >> $file
else
	while ! [[ $ics_install == 'Y' || $ics_install == 'N' ]] # While string is different or empty...
        do
                printf "Would you like to install IBM Common Services in this process? (\e[4mN\e[0m)o/(Y)es: "
                read ics_install
                ics_install=${ics_install:-N}
                if ! [[ $ics_install == 'Y' || $ics_install == 'N' ]]
                then
                        echo "Incorrect value"
                fi
        done
	if [[ $ics_install == 'Y' ]]
        then
                while [[ $ics_version_selected == '' ]]
                do
                        echo "Select ICS version to mirror:"
                        i=1
                        for ics_version in "${ics_versions[@]}"
                        do
                                echo "$i - $ics_version"
                                i=$((i+1))
                        done
                        read -p "Your choice?: " ics_version_selected
                	ics_version_selected=$(($ics_version_selected-1))
			(for e in "${ics_versions[@]}"; do [[ "$e" == "${ics_versions[$ics_version_selected]}" ]] && exit 0; done) && is_correct_selection=0 || is_correct_selection=1
	                if [[ $is_correct_selection -eq 1 || ics_version_selected -lt 0 ]]
        	        then
                	        ics_version_selected=''
	                echo "Incorrect choice"
        	        fi
                done
                echo "export GI_ICS_VERSION=$ics_version_selected" >> $file
	fi
fi
echo "export GI_ICS=$ics_install" >> $file
# OCP selection
if [[ $gi_install == 'Y' ]]
then
	IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_gi[$gi_version_selected]}
elif [[ $ics_install == 'Y' ]]
then
	IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_ics[$ics_version_selected]}
else
	declare -a ocp_versions=(0 1 2 3)
fi
while [[ $ocp_major_version == '' ]]
do
	echo "Select OCP version:"
	i=1
	for ocp_version in "${ocp_versions[@]}"
	do
		echo "$i - ${ocp_major_versions[$ocp_version]}"
		i=$((i+1))
	done
	read -p "Your choice?: " ocp_major_version
	ocp_major_version=$(($ocp_major_version-1))
	(for e in "${ocp_versions[@]}"; do [[ "$e" == "$ocp_major_version" ]] && exit 0; done) && is_correct_selection=0 || is_correct_selection=1
	if [[ $is_correct_selection -eq 1 || ocp_major_version -lt 0 ]]
	then
		ocp_major_version=''
		echo "Incorrect choice"
	fi
done
while [[ $ocp_release_decision != 'E' && $ocp_release_decision != 'S' ]]
do
        printf "Would you provide exact version OC to install [E] or use the latest stable (S)? (\e[4mE\e[0m)xact/(S)table: "
        read ocp_release_decision
        ocp_release_decision=${ocp_release_decision:-E}
        if [[ $ocp_release_decision == 'E' ]]
        then
                while [[ $ocp_release_minor == '' ]]
                do
			read -p "Insert minor version of OCP $ocp_major_version to install (must be existing one): " ocp_release_minor
                done
		ocp_release="${ocp_major_versions[${ocp_major_version}]}.${ocp_release_minor}"
        elif [[ $ocp_release_decision == 'S' ]]
        then
		ocp_release="${ocp_major_versions[${ocp_major_version}]}.latest"
        fi
done
echo "export GI_OCP_RELEASE=$ocp_release" >> $file
while ! [[ $is_master_only == 'Y' || $is_master_only == 'N' ]]
do
	printf "Is your installation the 3 nodes only (masters only)? (\e[4mN\e[0m)o/(Y)es: "
        read is_master_only
        is_master_only=${is_master_only:-N}
        if ! [[ $is_master_only == 'Y' || $is_master_only == 'N' ]]
        then
 	       echo "Incorrect value"
        fi
done
echo export GI_MASTER_ONLY=$is_master_only >> $file
# Time settings
while ! [[ $install_ntpd == 'Y' || $install_ntpd == 'N' ]]
do
        printf "Would you like setup NTP server on bastion? (\e[4mY\e[0m)es/(N)o: "
        read install_ntpd
        install_ntpd=${install_ntpd:-Y}
        if ! [[ $install_ntpd == 'Y' || $install_ntpd == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
if [[ $install_ntpd == 'N' ]]
then
        if [[ ! -z "$GI_NTP_SRV" ]]
        then
                read -p "Provide NTP server IP address [$GI_NTP_SRV] - insert new or confirm existing one <ENTER>: " new_ntp_server
                if [[ $new_ntp_server != '' ]]
                then
                        ntp_server=$new_ntp_server
                else
                        ntp_server=$GI_NTP_SRV
                fi
        else
                while [[ $ntp_server == '' ]]
                do
                        read -p "Insert NTP server IP address: " ntp_server
                done
        fi
        sed -i "s/^pool .*/pool $ntp_server iburst/g" /etc/chrony.conf
        systemctl enable chronyd
        systemctl restart chronyd
fi
while ! [[ $is_tz_ok == 'Y' ]]
do
        read -p "Your Timezone on bastion is set to `timedatectl show|grep Timezone|awk -F '=' '{ print $2 }'`, is it correct one [Y/N]: " is_tz_ok
        if [[ $is_tz_ok == 'N' ]]
        then
                read -p "Insert your Timezone in Linux format (i.e. Europe/Berlin): " new_tz
                timedatectl set-timezone $new_tz 2>/dev/null
                if [[ $? -eq 0 ]]
                then
                        is_tz_ok='Y'
                else
                        echo "You have inserted incorrect timezone specification, try again"
                fi
        fi

done
if [ $install_ntpd == 'Y' ]
then
        echo "*** Configuring NTP server on bastion - stratum 10 ***"
        while ! [[ $is_td_ok == 'Y' ]]
        do
                read -p "Current local time is `date`, is it correct one [Y/N]: " is_td_ok
                if [[ $is_td_ok == 'N' ]]
                then
                        read -p "Insert correct date and time in format \"2012-10-30 18:17:16\": " new_td
                        timedatectl set-ntp false
                        echo "NTP client is turned off"
                        timedatectl set-time "$new_td" 2>/dev/null
                        if [[ $? -eq 0 ]]
                        then
                                is_td_ok='Y'
                        else
                                echo "You have inserted incorrect time and date specification, try again"
                        fi
                fi
        done
else
        echo "Your current time is: `date`"
fi
# Collects Bastion and Subnet information
if [[ ! -z "$GI_BASTION_IP" ]]
then
        read -p "Bastion IP is set to [$GI_BASTION_IP] - insert new or confirm existing one <ENTER>: " new_bastion_ip
        if [[ $new_bastion_ip != '' ]]
        then
                bastion_ip=$new_bastion_ip
        fi
else
        while [[ $bastion_ip == '' ]]
        do
                read -p "Insert Bastion IP used to communicate with your OCP cluster: " bastion_ip
        done
fi
if [[ -z "$bastion_ip" ]]
then
        echo export GI_BASTION_IP=$GI_BASTION_IP >> $file
else
        echo export GI_BASTION_IP=$bastion_ip >> $file
fi
# Set NTP server variable
if [[ $install_ntpd == 'Y' && -z $bastion_ip ]]
then
        ntp_server=$GI_BASTION_IP
elif [[ $install_ntpd == 'Y' && ! -z $bastion_ip ]]
then
        ntp_server=$bastion_ip
fi
if [[ -z "$ntp_server" ]]
then
        echo export GI_NTP_SRV=$GI_NTP_SRV >> $file
else
        echo export GI_NTP_SRV=$ntp_server >> $file
fi
if [[ ! -z "$GI_BASTION_NAME" ]]
then
        read -p "Bastion name is set to [$GI_BASTION_NAME] - insert new or confirm existing one <ENTER>: " new_bastion_name
        if [[ $new_bastion_name != '' ]]
        then
                bastion_name=$new_bastion_name
        fi
else
        while [[ $bastion_name == '' ]]
        do
                read -p "Insert Bastion name used to communicate with Bootstrap server: " bastion_name
        done
fi
if [[ -z "$bastion_name" ]]
then
        echo export GI_BASTION_NAME=$GI_BASTION_NAME >> $file
else
        echo export GI_BASTION_NAME=$bastion_name >> $file
fi
if [[ ! -z "$GI_GATEWAY" ]]
then
        read -p "Current subnet gateway is [$GI_GATEWAY] - insert new or confirm existing one <ENTER>: " new_subnet_gateway
        if [[ $new_subnet_gateway != '' ]]
        then
                subnet_gateway=$new_subnet_gateway
        fi
else
        while [[ $subnet_gateway == '' ]]
        do
                read -p "Provide subnet gateway (default router): " subnet_gateway
        done
fi
if [[ -z "$subnet_gateway" ]]
then
        echo export GI_GATEWAY=$GI_GATEWAY >> $file
else
        echo export GI_GATEWAY=$subnet_gateway >> $file
fi

if [[ ! -z "$GI_DNS_FORWARDER" ]]
then
        read -p "Current DNS forwarder is set to [$GI_DNS_FORWARDER] - insert new or confirm existing one <ENTER>: " new_dns_forwarding
        if [[ $new_dns_forwarding != '' ]]
        then
                dns_forwarding=$new_dns_forwarding
        fi
else
        while [[ $dns_forwarding == '' ]]
        do
                read -p "Point DNS internal server to resolve public names: " dns_forwarding
        done
fi
if [[ -z "$dns_forwarding" ]]
then
        echo export GI_DNS_FORWARDER=$GI_DNS_FORWARDER >> $file
else
        echo export GI_DNS_FORWARDER=$dns_forwarding >> $file
fi
# Defines Bootstrap parameters
if [[ ! -z "$GI_BOOTSTRAP_IP" ]]
then
        read -p "Current Bootstrap IP is set to [$GI_BOOTSTRAP_IP] - insert new or confirm existing one <ENTER>: " new_boot_ip
        if [[ $new_boot_ip != '' ]]
        then
                boot_ip=$new_boot_ip
        fi
else
        while [[ $boot_ip == '' ]]
        do
                read -p "Insert Bootstrap IP: " boot_ip
        done
fi
if [[ -z "$boot_ip" ]]
then
        echo export GI_BOOTSTRAP_IP=$GI_BOOTSTRAP_IP >> $file
else
        echo export GI_BOOTSTRAP_IP=$boot_ip >> $file
fi
if [[ ! -z "$GI_BOOTSTRAP_MAC_ADDRESS" ]]
then
        read -p "Current Bootstrap MAC address is set to [$GI_BOOTSTRAP_MAC_ADDRESS] - insert new or confirm existing one <ENTER>: " new_boot_mac
        if [[ $new_boot_mac != '' ]]
        then
                boot_mac=$new_boot_mac
        fi
else
        while [[ $boot_mac == '' ]]
        do
                read -p "Insert Bootstrap MAC address: " boot_mac
        done
fi
if [[ -z "$boot_mac" ]]
then
        echo export GI_BOOTSTRAP_MAC_ADDRESS=$GI_BOOTSTRAP_MAC_ADDRESS >> $file
else
        echo export GI_BOOTSTRAP_MAC_ADDRESS=$boot_mac >> $file
fi
if [[ ! -z "$GI_BOOTSTRAP_NAME" ]]
then
        read -p "Current bootstrap name is set to [$GI_BOOTSTRAP_NAME] - insert new or confirm existing one <ENTER>: " new_boot_name
        if [[ $new_boot_name != '' ]]
        then
                boot_name=$new_boot_name
        fi
else
        while [[ $boot_name == '' ]]
        do
                read -p "Insert OCP bootstrap name [boot]: " boot_name
                boot_name=${boot_name:-boot}
        done
fi
if [[ -z $boot_name ]]
then
        echo export GI_BOOTSTRAP_NAME=$GI_BOOTSTRAP_NAME >> $file
else
        echo export GI_BOOTSTRAP_NAME=$boot_name >> $file
fi
# Defines master nodes parameters
declare -a master_ip_arr
while [[ ${#master_ip_arr[@]} -ne 3 ]]
do
        if [ ! -z "$GI_MASTER_IP" ]
        then
                read -p "Current list of master node(s) IP is [$GI_MASTER_IP] - insert three IP's (comma separated) or confirm existing <ENTER>: " new_master_ip
                if [[ $new_master_ip != '' ]]
                then
                        master_ip=$new_master_ip
                else
                        master_ip=$GI_MASTER_IP
                fi
        else
                read -p "Insert three IP address(es) of master node(s) (comma separated): " master_ip
        fi
        IFS=',' read -r -a master_ip_arr <<< $master_ip
        GI_MASTER_IP=$master_ip
done
echo export GI_MASTER_IP=$master_ip >> $file
declare -a master_mac_arr
while [[ ${#master_mac_arr[@]} -ne 3 ]]
do
        if [ ! -z "$GI_MASTER_MAC_ADDRESS" ]
        then
                read -p "Current master node MAC address list is set to [$GI_MASTER_MAC_ADDRESS] - insert three MAC address(es) or confirm existing one <ENTER>: " new_master_mac
                if [[ $new_master_mac != '' ]]
                then
                        master_mac=$new_master_mac
                else
                        master_mac=$GI_MASTER_MAC_ADDRESS
                fi
        else
                read -p "Insert three MAC address(es) of master node(s): " master_mac
        fi
        IFS=',' read -r -a master_mac_arr <<< $master_mac
        GI_MASTER_MAC_ADDRESS=$master_mac
done
echo export GI_MASTER_MAC_ADDRESS=$master_mac >> $file
declare -a master_name_arr
while [[ ${#master_name_arr[@]} -ne 3 ]]
do
        if [ ! -z "$GI_MASTER_NAME" ]
        then
                read -p "Current master node name list is set to [$GI_MASTER_NAME] - insert three master name(s) or confirm existing one <ENTER>: " new_master_name
                if [[ $new_master_name != '' ]]
                then
                        master_name=$new_master_name
                else
                        master_name=$GI_MASTER_NAME
                fi
        else
                read -p "Insert three master node name(s): " master_name
        fi
        IFS=',' read -r -a master_name_arr <<< $master_name
        GI_MASTER_NAME=$master_name
done
echo export GI_MASTER_NAME=$master_name >> $file
# Collects storage information
while [[ $storage_type != 'O' && "$storage_type" != 'R' ]]
do
	if [[ ! -z "$GI_STORAGE_TYPE" ]]
        then
        	read -p "Cluster storage is set to [$GI_STORAGE_TYPE], insert (R) for Rook-Ceph, (O) for OCS or confirm current selection <ENTER>: " storage_type
                if [[ $storage_type == '' ]]
                then
                	storage_type=$GI_STORAGE_TYPE
                fi
        else
                read -p "What kind of cluster storage type will be deployed (O) for OCS (OpenShift Cluster Storage) or (R) for Rook-Ceph: " storage_type
        fi
done
echo export GI_STORAGE_TYPE=$storage_type >> $file
while [[ $storage_device == '' || -z "$storage_device" ]]
do
	if [[ ! -z "$GI_STORAGE_DEVICE" ]]
        then
        	read -p "Cluster device for storage virtualization set to [$GI_STORAGE_DEVICE], insert new cluster storage device specification or confirm existing one <ENTER>: " storage_device
                if [[ $storage_device == '' ]]
                then
                	storage_device=$GI_STORAGE_DEVICE
                fi
        else
                read -p "Provide cluster device specification for storage virtualization (for example sdb or nvmne1): " storage_device
        fi
done
echo export GI_STORAGE_DEVICE=$storage_device >> $file
while [[ $storage_device_size == '' || -z "$storage_device_size" ]]
do
	if [[ ! -z "$GI_STORAGE_DEVICE_SIZE" ]]
        then
        	read -p "Maximum space for available for for storage virtualization on all disks is set to [$GI_STORAGE_DEVICE_SIZE] GB, insert new maximum space on cluster device for virtualization (in GB) or confirm existing one <ENTER>: " storage_device_size
                if [[ $storage_device_size == '' ]]
                then
                	storage_device_size=$GI_STORAGE_DEVICE_SIZE
                fi
        else
        	read -p "Provide maximum space on cluster devices for storage virtualization (for example 300) in GB: " storage_device_size
        fi
done
echo export GI_STORAGE_DEVICE_SIZE=$storage_device_size >> $file
if [[ $storage_type == "O" && $is_master_only == 'N' ]]
then
	while ! [[ $ocs_tainted == "Y" || $ocs_tainted == "N" ]]
        do
        	printf "Would you like isolate (taint) OCS nodes in the OCP cluster (\e[4mN\e[0m)o/(Y)es?: "
                read ocs_tainted
                ocs_tainted=${ocs_tainted:-N}
                if ! [[ $ocs_tainted == "Y" || $ocs_tainted == "N" ]]
                then
                	echo "Incorrect value, insert Y or N"
                fi
	done
else
        ocs_tainted="N"
fi
echo export GI_OCS_TAINTED=$ocs_tainted >> $file
if [[ $is_master_only == 'N' ]]
then
	if [[ $ocs_tainted == 'Y' ]]
        then
                declare -a ocs_ip_arr
                while [[ ${#ocs_ip_arr[@]} -ne 3 ]]
                do
                        if [ ! -z "$GI_OCS_IP" ]
                        then
                                read -p "Current OCS node IP list is set to [$GI_OCS_IP] - insert 3 IP's (comma separated) or confirm existing <ENTER>: " new_ocs_ip
                                if [[ $new_ocs_ip != '' ]]
                                then
                                        ocs_ip=$new_ocs_ip
                                else
                                        ocs_ip=$GI_OCS_IP
                                fi
                        else
                                read -p "Insert 3 IP addresses of OCS nodes (comma separated): " ocs_ip
                        fi
                        IFS=',' read -r -a ocs_ip_arr <<< $ocs_ip
                        GI_OCS_IP=$ocs_ip
                done
                echo export GI_OCS_IP=$ocs_ip >> $file
                declare -a ocs_mac_arr
                while [[ ${#ocs_mac_arr[@]} -ne 3 ]]
                do
                        if [ ! -z "$GI_OCS_MAC_ADDRESS" ]
                        then
                                read -p "Current OCS MAC address list is set to [$GI_OCS_MAC_ADDRESS] - insert 3 MAC addresses or confirm existing one <ENTER>: " new_ocs_mac
                                if [[ $new_ocs_mac != '' ]]
                                then
                                        ocs_mac=$new_ocs_mac
                                else
                                        ocs_mac=$GI_OCS_MAC_ADDRESS
                                fi
                        else
                                read -p "Insert 3 MAC addresses of OCS nodes (comma separated): " ocs_mac
                        fi
                        IFS=',' read -r -a ocs_mac_arr <<< $ocs_mac
                        GI_OCS_MAC_ADDRESS=$ocs_mac
                done
                echo export GI_OCS_MAC_ADDRESS=$ocs_mac >> $file
                declare -a ocs_name_arr
                while [[ ${#ocs_name_arr[@]} -ne 3 ]]
                do
                        if [ ! -z "$GI_OCS_NAME" ]
                        then
                                read -p "Current OCS node name list is set to [$GI_OCS_NAME] - insert 3 OCS node names or confirm existing one <ENTER>: " new_ocs_name
                                if [[ $new_ocs_name != '' ]]
                                then
                                        ocs_name=$new_ocs_name
                                else
                                        ocs_name=$GI_OCS_NAME
                                fi
                        else
                                read -p "Insert 3 OCS node names (comma separated): " ocs_name
                        fi
                        IFS=',' read -r -a ocs_name_arr <<< $ocs_name
                        GI_OCS_NAME=$ocs_name
                done
                echo export GI_OCS_NAME=$ocs_name >> $file
        fi
        if [[ ocs_tainted == 'N' ]]
        then
                m_worker_number=3
        else
                m_worker_number=2
        fi
	echo "Define number of workers, you must set minimum $m_worker_number of workers."
        while ! [[ $w_number -ge $m_worker_number ]]
        do

                printf "How many additional workers will you deploy [$m_worker_number]?: "
                read w_number
                w_number=${w_number:-$m_worker_number}
                if ! [[ $w_number -ge $m_worker_number ]]
                then
                        echo "Incorrect value"
                fi
        done
        declare -a worker_ip_arr
        while [[ $w_number != ${#worker_ip_arr[@]} ]]
        do
                if [ ! -z "$GI_WORKER_IP" ]
                then
                        read -p "Current list of worker nodes IP list is set to [$GI_WORKER_IP] - insert $w_number IP's (comma separated) or confirm existing <ENTER>: " new_worker_ip
                        if [[ $new_worker_ip != '' ]]
                        then
                                worker_ip=$new_worker_ip
                        else
                                worker_ip=$GI_WORKER_IP
                        fi
                else
                        read -p "Insert $w_number IP addresses of worker nodes (comma separated): " worker_ip
                fi
                IFS=',' read -r -a worker_ip_arr <<< $worker_ip
                GI_WORKER_IP=$worker_ip
        done
        echo export GI_WORKER_IP=$worker_ip >> $file
        declare -a worker_mac_arr
        while [[ $w_number != ${#worker_mac_arr[@]} ]]
        do
                if [ ! -z "$GI_WORKER_MAC_ADDRESS" ]
                then
                        read -p "Current worker node MAC address list is set to [$GI_WORKER_MAC_ADDRESS] - insert $w_number MAC addresses or confirm existing one <ENTER>: " new_worker_mac
                        if [[ $new_worker_mac != '' ]]
                        then
                                worker_mac=$new_worker_mac
                        else
                                worker_mac=$GI_WORKER_MAC_ADDRESS
                        fi
                else
                        read -p "Insert $w_number MAC addresses of worker nodes: " worker_mac
                fi
                IFS=',' read -r -a worker_mac_arr <<< $worker_mac
                GI_WORKER_MAC_ADDRESS=$worker_mac
        done
	echo export GI_WORKER_MAC_ADDRESS=$worker_mac >> $file
        declare -a worker_name_arr
        while [[ $w_number != ${#worker_name_arr[@]} ]]
        do
                if [ ! -z "$GI_WORKER_NAME" ]
                then
                        read -p "Current worker node name list is set to [$GI_WORKER_NAME] - insert $w_number worker names or confirm existing one <ENTER>: " new_worker_name
                        if [[ $new_worker_name != '' ]]
                        then
                                worker_name=$new_worker_name
                        else
                                worker_name=$GI_WORKER_NAME
                        fi
                else
                        read -p "Insert $w_number worker node names: " worker_name
                fi
                IFS=',' read -r -a worker_name_arr <<< $worker_name
                GI_WORKER_NAME=$worker_name
        done
        echo export GI_WORKER_NAME=$worker_name >> $file
fi
# Defines DHCP IP range
if [[ ! -z "$GI_DHCP_RANGE_START" ]]
then
        read -p "First DHCP lease address is set to [$GI_DHCP_RANGE_START] - insert new or confirm existing one <ENTER>: " new_dhcp_start
        if [[ $new_dhcp_start != '' ]]
        then
                dhcp_start=$new_dhcp_start
        fi
else
        while [[ $dhcp_start == '' ]]
        do
                read -p "Insert first IP address served by DHCP server (range must include bootstrap and ocp IP's): " dhcp_start
        done
fi
if [[ -z "$dhcp_start" ]]
then
        echo export GI_DHCP_RANGE_START=$GI_DHCP_RANGE_START>> $file
else
        echo export GI_DHCP_RANGE_START=$dhcp_start >> $file
fi
if [[ ! -z "$GI_DHCP_RANGE_STOP" ]]
then
        read -p "Last DHCP lease address is set to [$GI_DHCP_RANGE_STOP] - insert new or confirm existing one <ENTER>: " new_dhcp_end
        if [[ $new_dhcp_end != '' ]]
        then
                dhcp_end=$new_dhcp_end
        fi
else
        while [[ $dhcp_end == '' ]]
        do
                read -p "Insert last IP address served by DHCP server (range must include bootstrap and ocp IP's): " dhcp_end
        done
fi
if [[ -z "$dhcp_end" ]]
then
        echo export GI_DHCP_RANGE_STOP=$GI_DHCP_RANGE_STOP >> $file
else
        echo export GI_DHCP_RANGE_STOP=$dhcp_end >> $file
fi
# Defines network boot device
if [[ ! -z "$GI_NETWORK_INTERFACE" ]]
then
        read -p "Bootstrap and cluster node booting NIC device is set to [$GI_NETWORK_INTERFACE] - insert new or confirm existing one <ENTER>: " new_machine_nic
        if [[ $new_machine_nic != '' ]]
        then
                machine_nic=$new_machine_nic
        fi
else
        while [[ $machine_nic == '' ]]
        do
                read -p "Provide bootstrap and cluster node booting NIC device name (for instance ens192): " machine_nic
        done
fi
if [[ -z "$machine_nic" ]]
then
        echo export GI_NETWORK_INTERFACE=$GI_NETWORK_INTERFACE >> $file
else
        echo export GI_NETWORK_INTERFACE=$machine_nic >> $file
fi
# Defines machine boot disk device
if [[ ! -z "$GI_BOOT_DEVICE" ]]
then
        read -p "Bootstrap and cluster nodes root disk device is set to [$GI_BOOT_DEVICE] - insert new or confirm existing one <ENTER>: " new_machine_disk
        if [[ $new_machine_disk != '' ]]
        then
                machine_disk=$new_machine_disk
        fi
else
        while [[ $machine_disk == '' ]]
        do
                read -p "Provide bootstrap and cluster node root disk device for Core OS installation (for instance sda or nvme0n0): " machine_disk
        done
fi
if [[ -z "$machine_disk" ]]
then
        echo export GI_BOOT_DEVICE=$GI_BOOT_DEVICE >> $file
else
        echo export GI_BOOT_DEVICE=$machine_disk >> $file
fi
# Defines inter-cluster network
if [[ ! -z "$GI_OCP_CIDR" ]]
then
        read -p "Inter-cluster CIDR is set to [$GI_OCP_CIDR] - insert new or confirm existing one <ENTER>: " new_ocp_cidr
        if [[ $new_ocp_cidr != '' ]]
        then
                ocp_cidr=$new_ocp_cidr
        fi
else
        while [[ $ocp_cidr == '' ]]
        do
                read -p "Insert inter-cluster CIDR [10.128.0.0/16]: " ocp_cidr
                ocp_cidr=${ocp_cidr:-10.128.0.0/16}
        done
fi
if [[ -z "$ocp_cidr" ]]
then
        echo export GI_OCP_CIDR=$GI_OCP_CIDR >> $file
else
        echo export GI_OCP_CIDR=$ocp_cidr >> $file
fi
if [[ ! -z "$GI_OCP_CIDR_MASK" ]]
then
        read -p "Inter-cluster CIDR subnet mask is set to [$GI_OCP_CIDR_MASK] - insert new or confirm existing one <ENTER>: " new_ocp_cidr_mask
        if [[ $new_ocp_cidr_mask != '' ]]
        then
                ocp_cidr_mask=$new_ocp_cidr_mask
        fi
else
        while [[ $ocp_cidr_mask == '' ]]
        do
                read -p "Insert pod's subnet mask [23]: " ocp_cidr_mask
                ocp_cidr_mask=${ocp_cidr_mask:-23}
        done
fi
if [[ -z "$ocp_cidr_mask" ]]
then
        echo export GI_OCP_CIDR_MASK=$GI_OCP_CIDR_MASK >> $file
else
        echo export GI_OCP_CIDR_MASK=$ocp_cidr_mask >> $file
fi
# Gets Redhat Pull Secret
if [[ $use_air_gap == 'N' ]]
then
        if [[ ! -z "$GI_RHN_SECRET" ]]
        then
                read -p "RedHat pull secret is set to [$GI_RHN_SECRET] - insert new or confirm existing one <ENTER>: " new_rhn_secret
                if [[ $new_rhn_secret != '' ]]
                then
                        rhn_secret=$new_rhn_secret
                else
                        rhn_secret=$GI_RHN_SECRET
                fi
        else
                while [[ $rhn_secret == '' ]]
                do
                        read -p "Insert RedHat pull secret (use this link to get access to it https://cloud.redhat.com/openshift/install): " rhn_secret
                done
        fi
        if [[ -z "$rhn_secret" ]]
        then
                echo "export GI_RHN_SECRET='$GI_RHN_SECRET'" >> $file
        else
                echo "export GI_RHN_SECRET='$rhn_secret'" >> $file
        fi
fi
# Gets OCP credentials created during installation (to avoid use the kubesystem account)
if [[ ! -z "$GI_OCADMIN" ]]
then
        read -p "OpenShift admin account name is set to [$GI_OCADMIN] - insert new or confirm existing one <ENTER>: " new_ocp_admin
        if [[ $new_ocp_admin != '' ]]
        then
                ocp_admin=$new_ocp_admin
        fi
else
        while [[ $ocp_admin == '' ]]
        do
                read -p "Insert a new OpenShift admin account name [ocadmin]: " ocp_admin
                ocp_admin=${ocp_admin:-ocadmin}
        done
fi
if [[ -z "$ocp_admin" ]]
then
        echo export GI_OCADMIN=$GI_OCADMIN >> $file
else
        echo export GI_OCADMIN=$ocp_admin >> $file
fi
while [[ $ocp_password == '' ]]
do
        read -sp "Insert a new OpenShift $ocp_admin password: " ocp_password
        echo -e '\n'
done
echo "export GI_OCADMIN_PWD='$ocp_password'" >> $file

