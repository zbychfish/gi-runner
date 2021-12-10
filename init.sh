#!/bin/bash

GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
mkdir -p $GI_TEMP
file=variables.sh
declare -a gi_versions=(3.0.0 3.0.1 3.0.2 3.1.0)
declare -a ics_versions=(3.7.4 3.8.1 3.9.1 3.10.0 3.11.0 3.12.1 3.13.0)
declare -a bundled_in_gi_ics_versions=(0 2 3 4)
declare -a ocp_major_versions=(4.6 4.7 4.8 4.9)
declare -a ocp_supported_by_gi=(0 0:1 0:1 0:1:2)
declare -a ocp_supported_by_ics=(0:1 0:1 0:1:2 0:1:2 0:1:2 0:1:2:3 0:1:2:3)
declare -a gi_sizes=(values-poc-lite values-dev values-small)

function get_ocp_domain() {
        if [[ ! -z "$GI_DOMAIN" ]]
        then
                read -p "Cluster domain is set to [$GI_DOMAIN] - insert new or confirm existing one <ENTER>: " new_ocp_domain
                if [[ $new_ocp_domain != '' ]]
                then
                        ocp_domain=$new_ocp_domain
                else
                        ocp_domain=$GI_DOMAIN
                fi
        else
                while [[ $ocp_domain == '' ]]
                do
                        read -p "Insert cluster domain (your private domain name), like ocp.io.priv: " ocp_domain
                        ocp_domain=${ocp_domain:-ocp.io.priv}
                done
        fi
        if [[ -z "$ocp_domain" ]]
        then
                echo export GI_DOMAIN=$GI_DOMAIN >> $file
		ocp_domain=$GI_DOMAIN
        else
                echo export GI_DOMAIN=$ocp_domain >> $file
        fi
}

function switch_dnf_sync_off() {
	if [[ `grep "metadata_timer_sync=" /etc/dnf/dnf.conf|wc -l` -eq 0 ]]
	then
		echo "metadata_timer_sync=0" >> /etc/dnf/dnf.conf
	else
		sed 's/.*metadata_timer_sync=.*/metadata_timer_sync=0/' /etc/dnf/dnf.conf
	fi
}

# Check bastion OS
echo "*** Checking OS release ***"
if [[ `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1}'` != 'Fedora' ]]
then
        echo "*** ERROR ***"
        echo "Your bastion machine is not Fedora OS - please use the supported Operating System"
        exit 1
else
        echo "Your system is `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1}'` - progressing ..."
fi

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
	switch_dnf_sync_off
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
	echo "- ICS 3.11.0 for GI 3.1.0"
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
if [[ $use_air_gap != 'Y' ]]
then
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
else
        while [[ $ocp_release_minor == '' ]]
        do
                read -p "Insert minor version of OCP $ocp_major_version to install (must be existing one): " ocp_release_minor
        done
        ocp_release="${ocp_major_versions[${ocp_major_version}]}.${ocp_release_minor}"
fi
get_ocp_domain
echo "export GI_OCP_RELEASE=$ocp_release" >> $file
echo "OCP certificate must refer globaly to each name in apps subdomain."
echo "Alternate Subject Name must be set to: \"*.apps.${ocp_domain}\"."
echo "You need provide full paths to CA, certificate and private key."
while ! [[ $ocp_ext_ingress == 'Y' || $ocp_ext_ingress == 'N' ]]
do
	printf  "Would you like add own certificate for OCP ingress? (\e[4mN\e[0m)o/(Y)es: "
	read ocp_ext_ingress
	ocp_ext_ingress=${ocp_ext_ingress:-N}
done
echo "export GI_OCP_IN=$ocp_ext_ingress" >> $file
if [[ $ocp_ext_ingress == 'Y' ]]
then
	result=1
	while [[ $result -ne 0 ]]
	do
		read -p "Insert full path to CA certificate which singned the OCP certificate: " ocp_ca
		openssl x509 -in $ocp_ca -text -noout
		result=$?
		if [[ $result -ne 0 ]]
		then
			echo "Certificate cannot be validated."
		fi
	done
	result=1
	while [[ $result -ne 0 ]]
	do
		read -p "Insert full path to OCP ingres certificate: " ocp_cert
		openssl x509 -in $ocp_cert -text -noout
		result=$?
		if [[ $result -eq 0 ]]
		then
			openssl verify -CAfile $ocp_ca $ocp_cert
			result=$?
			if [[ $result -ne 0 ]]
			then
				echo "Certificate is not signed by provided CA"
			fi
		else
			echo "Certificate cannot be validated."
		fi
	done
	modulus_cert=`openssl x509 -noout -modulus -in $ocp_cert`
	result=1
	while [[ $result -ne 0 ]]
	do
		read -p "Insert full path to private key of OCP certificate: " ocp_key
		openssl rsa -in $ocp_key -check
		result=$?
		if [[ $result -eq 0 ]]
		then
			if [[ `openssl rsa -noout -modulus -in $ocp_key` != $modulus_cert ]]
			then
				echo "Key does not correspond to OCP certificate"
				result=1
			fi
		else
			echo "Key cannot be validated."
		fi
	done
	echo "export GI_OCP_IN_CA=$ocp_ca" >> $file
	echo "export GI_OCP_IN_CERT=$ocp_cert" >> $file
	echo "export GI_OCP_IN_KEY=$ocp_key" >> $file
fi
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
# GI parameters
if [[ $gi_install == 'Y' ]]
then
	if [[ $use_air_gap == 'N' ]]
        then
                if [[ ! -z "$GI_IBM_SECRET" ]]
                then
                        read -p "IBM Cloud secret is set to [$GI_IBM_SECRET] - insert new or confirm existing one <ENTER>: " new_ibm_secret
                        if [[ $new_ibm_secret != '' ]]
                        then
                                ibm_secret=$new_ibm_secret
                        else
                                ibm_secret=$GI_IBM_SECRET
                        fi
                else
                        while [[ $ibm_secret == '' ]]
                        do
                                read -p "Insert IBM Cloud secret: " ibm_secret
                        done
                fi
                if [[ -z "$ibm_secret" ]]
                then
                        echo "export GI_IBM_SECRET='$GI_IBM_SECRET'" >> $file
                else
                        echo "export GI_IBM_SECRET='$ibm_secret'" >> $file
                fi
        fi
        while [[ ( -z $gi_size_selected ) || ! " ${gi_sizes[@]} " =~ " ${gi_sizes[$gi_size_selected]} " ]]
        do
                echo "Select GI deployment size:"
                i=1
                for gi_size in "${gi_sizes[@]}"
                do
                        echo "$i - $gi_size"
                        i=$((i+1))
                done
                read -p "Your choice?: " gi_size_selected
                gi_size_selected=$(($gi_size_selected-1))
        done
	while [[ $gi_ds_size == '' || -z "$gi_ds_size" ]]
        do
                if [[ ! -z "$GI_DATA_STORAGE_SIZE" ]]
                then
                        read -p "Size of GI data PVC is set to [$GI_DATA_STORAGE_SIZE] GB, insert new value (in GB, it should be not larger than 70% of total cluster storage size) or confirm existing one <ENTER>: " gi_ds_size
                        if [[ $gi_ds_size == '' ]]
                        then
                                gi_ds_size=$GI_DATA_STORAGE_SIZE
                        fi
                else
                        read -p "Provide size of GI data PVC (for example 300, should not exceed 70% of total cluster storage size) in GB: " gi_ds_size
                fi
        done
        echo "export GI_DATA_STORAGE_SIZE=$gi_ds_size" >> $file
        echo "export GI_SIZE_GI=${gi_sizes[$gi_size_selected]}" >> $file
        #echo "export GI_INSTALL_GI=$gi_install" >> $file
        echo "export GI_ICS_OPERANDS=N,N,Y,Y,Y,N,N,N,N" >> $file
        #echo "export GI_ICS=Y" >> $file
        while [[ $ics_password == '' ]]
        do
                read -sp "Insert IBM Common Services admin user password: " ics_password
                echo -e '\n'
        done
        echo "export GI_ICSADMIN_PWD='$ics_password'" >> $file
        if [[ ! -z "$GI_NAMESPACE_GI" ]]
        then
                read -p "Guardium Insights namespace is set to [$GI_NAMESPACE_GI] - insert new or confirm existing one <ENTER>: " new_gi_namespace
                if [[ $new_gi_namespace != '' ]]
                then
                        gi_namespace=$new_gi_namespace
                fi
        else
                while [[ $gi_namespace == '' ]]
                do
                        read -p "Insert Guardium Insights namespace name (maximum 10 characters): " gi_namespace
                done
        fi
	if [[ -z "$gi_namespace" ]]
        then
                echo export GI_NAMESPACE_GI=$GI_NAMESPACE_GI >> $file
        else
                echo export GI_NAMESPACE_GI=$gi_namespace >> $file
        fi
        if [[ ! -z "$GI_DB2_NODES" ]]
        then
                read -p "Current list of DB2 nodes is set to [$GI_DB2_NODES] - insert list of DB2 nodes (comma separated) or confirm existing <ENTER>: " new_db2_nodes
                if [[ $new_db2_nodes != '' ]]
                then
			declare -a db2_nodes_arr=()
                	while [[ ${#db2_nodes_arr[@]} -lt 1 || ${#db2_nodes_arr[@]} -gt 3 ]]
                	do
                        	declare -a db2_nodes_arr=()
                        	read -p "Insert DB2 nodes list (comma separated): " db2_nodes
                        	IFS=","
                        	for element in $db2_nodes;do db2_nodes_arr+=( $element );done
                	done
                else
                        db2_nodes=$GI_DB2_NODES
                fi
        else
		declare -a db2_nodes_arr=()
		while [[ ${#db2_nodes_arr[@]} -lt 1 || ${#db2_nodes_arr[@]} -gt 3 ]]
		do
			declare -a db2_nodes_arr=()
                	read -p "Insert DB2 nodes list (comma separated): " db2_nodes
			IFS=","
			for element in $db2_nodes;do db2_nodes_arr+=( $element );done
		done
        fi
        echo export GI_DB2_NODES=$db2_nodes >> $file
        while ! [[ $db2_enc == 'Y' || $db2_enc == 'N' ]]
        do
                if [[ $gi_version_selected -ge 2 ]]
                then
                        if [[ ! -z "$GI_DB2_ENCRYPTED" ]]
                        then
                                read -p "DB2 encryption is set to [$GI_DB2_ENCRYPTED] - should be DB2u tablespace encrypted (YES/NO) or confirm current value <ENTER>: " new_db2_enc
                                if [[ $new_db2_enc != '' ]]
                                then
                                        db2_enc=$new_db2_enc
                                else
                                        db2_enc=$GI_DB2_ENCRYPTED
                                fi
                        else
                                printf "Should be DB2u tablespace encrypted? (\e[4mN\e[0m)o/(Y)es: "
                                read db2_enc
                                db2_enc=${db2_enc:-N}
                        fi
                        if ! [[ $db2_enc == 'Y' || $db2_enc == 'N' ]]
                        then
                                echo "Incorrect value"
                        fi
                else
                        db2_enc='Y'
                fi
        done
        echo export GI_DB2_ENCRYPTED=$db2_enc >> $file
        while ! [[ $stap_supp == 'Y' || $stap_supp == 'N' ]]
        do
                if [[ $gi_version_selected -ge 3 ]]
                then
                        if [[ ! -z "$GI_STAP_STREAMING" ]]
                        then
                                read -p "STAP direct streaming to GI is set to [$GI_STAP_STREAMING] - would you like to enable this feature (YES/NO) or confirm current value <ENTER>: " new_stap_supp
                                if [[ $new_stap_supp != '' ]]
                                then
                                        stap_supp=$new_stap_supp
                                else
                                        stap_supp=$GI_STAP_STREAMING
                                fi
                        else
                                printf "Should be enabled the direct streaming from STAP's? (\e[4mY\e[0m)es/(N)o: "
                                read stap_supp
                                stap_supp=${stap_supp:-Y}
                        fi
                        if ! [[ $stap_supp == 'Y' || $stap_supp == 'N' ]]
                        then
                                echo "Incorrect value"
                        fi
                else
                        stap_supp='N'
                fi
        done
        echo export GI_STAP_STREAMING=$stap_supp >> $file
elif [[ $gi_install=='N' && $ics_install == 'Y' ]]
then
	ics_sizes="S M L"
        while [[ ( -z $size_selected ) || ! " ${ics_sizes[@]} " =~ " ${size_selected} " ]]
        do
	        printf "Select ICS deployment size (\e[4mS\e[0m)mall/(M)edium/(L)arge: "
                read size_selected
                size_selected=${size_selected:-S}
                if ! [[ " ${ics_sizes[@]} " =~ " ${size_selected} " ]]
                then
        	        echo "Incorrect value"
               fi
        done
        echo "export GI_ICS_SIZE=$size_selected" >> $file
        while [[ $ics_password == '' ]]
        do
        	read -sp "Insert IBM Common Services admin user password: " ics_password
                echo -e '\n'
        done
        echo "export GI_ICSADMIN_PWD='$ics_password'" >> $file
        # Define ICS operand list
        declare -a ics_ops
	while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        do
	        printf "Would you like to install zen operand with ICS?: (\e[4mN\e[0m)o/(Y)es: "
                read op_option
                op_option=${op_option:-N}
        done
        ics_ops+=($op_option)
        op_option=''
        while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        do
        	printf "Would you like to install Monitoring operand with ICS?: (N)o/(\e[4mY\e[0m)es: "
               	read op_option
               	op_option=${op_option:-Y}
        done
        ics_ops+=($op_option)
        op_option=''
        while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        do
        	printf "Would you like to install Event Streams operand with ICS?: (N)o/(\e[4mY\e[0m)es: "
               	read op_option
                op_option=${op_option:-Y}
        done
        ics_ops+=($op_option)
        op_option=''
        while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        do
         	printf "Would you like to install Logging operand with ICS?: (N)o/(\e[4mY\e[0m)es: "
                read op_option
                op_option=${op_option:-Y}
        done
        ics_ops+=($op_option)
        op_option=''
        while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        do
        	printf "Would you like to install MongoDB operand with ICS?: (N)o/(\e[4mY\e[0m)es: "
                read op_option
                op_option=${op_option:-Y}
        done
        ics_ops+=($op_option)
	if [[ $ics_version_selected -ge 5 ]]
	then
        	op_option=''
		while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
         	do
	 		printf "Would you like to install User Data Services operand with ICS?: (\e[4mN\e[0m)o/(Y)es: "
                	read op_option
                	op_option=${op_option:-N}
         	done
         	ics_ops+=($op_option)
	else
		ics_ops+=("N")
	fi
	if [[ $ics_version_selected -ge 5 ]]
        then
        	op_option=''
		while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        	do
			printf "Would you like to install Apache Spark operand with ICS?: (\e[4mN\e[0m)o/(Y)es: "
                	read op_option
                	op_option=${op_option:-N}
        	done
        	ics_ops+=($op_option)
	else
		ics_ops+=("N")
	fi
	if [[ $ics_version_selected -ge 5 ]]
        then
       		op_option=''
		while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
        	do
			printf "Would you like to install IBM API Catalog operand with ICS?: (\e[4mN\e[0m)o/(Y)es: "
                	read op_option
                	op_option=${op_option:-N}
        	done
        	ics_ops+=($op_option)
	else
		ics_ops+=("N")
	fi
	if [[ $ics_version_selected -ge 6 ]]
        then
                op_option=''
                while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
                do
                        printf "Would you like to install Business Teams operand with ICS?: (\e[4mN\e[0m)o/(Y)es: "
                        read op_option
                        op_option=${op_option:-N}
                done
                ics_ops+=($op_option)
        else
                ics_ops+=("N")
        fi

        echo export GI_ICS_OPERANDS=`echo ${ics_ops[@]}|awk 'BEGIN { FS= " ";OFS="," } { $1=$1 } 1'` >> $file
fi
while ! [[ $install_ldap == 'Y' || $install_ldap == 'N' ]] # While string is different or empty...
do
        printf "Would you like install OpenLDAP for example as Guardium Insights identity source? (\e[4mY\e[0m)es/(N)o: "
        read install_ldap
        install_ldap=${install_ldap:-Y}
        if ! [[ $install_ldap == 'Y' || $install_ldap == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
echo "export GI_INSTALL_LDAP=${install_ldap}" >> $file
if [ $install_ldap == 'Y' ]
then
	if [[ ! -z "$GI_LDAP_DEPLOYMENT" ]]
	then
		if [[ "$GI_LDAP_DEPLOYMENT" == "C" ]]
		then
			ldap_inst_type = "openshift"
		else
			ldap_inst_type = "bastion"
		fi
		read -p "You decided to install openldap on $ldap_inst_type  - insert (C)ontainer or (S)tandalone bastion or confirm existing and press <ENTER>: " new_ldap_depl
		if [[ $new_ldap_depl != '' ]]
                then
                        ldap_depl=$new_ldap_depl
                fi
	else
		while ! [[ $ldap_depl == 'C' || $ldap_depl == 'S' ]]
                do
			printf "Decide where LDAP instance should be deployed (as container on OpenShift or as standalone installation on bastion? (\e[4mC\e[0m)ontainer/(S)tandalone: "
			read ldap_depl
			ldap_depl=${ldap_depl:-C}
		done
	fi
	if [[ -z "$ldap_depl" ]]
        then
                echo export GI_LDAP_DEPLOYMENT=$GI_LDAP_DEPLOYMENT >> $file
        else
                echo export GI_LDAP_DEPLOYMENT=$ldap_depl >> $file
        fi
        if [[ ! -z "$GI_LDAP_DOMAIN" ]]
        then
                read -p "LDAP organization DN is set to [$GI_LDAP_DOMAIN] - insert new or confirm existing one <ENTER>: " new_ldap_domain
                if [[ $new_ldap_domain != '' ]]
                then
                        ldap_domain=$new_ldap_domain
                fi
        else
                read -p "Insert LDAP organization DN (for example: DC=io,DC=priv): " ldap_domain
        fi
        if [[ -z "$ldap_domain" ]]
        then
                echo export GI_LDAP_DOMAIN=$GI_LDAP_DOMAIN >> $file
        else
                echo export GI_LDAP_DOMAIN=$ldap_domain >> $file
        fi
        if [[ ! -z "$GI_LDAP_USERS" ]]
        then
                read -p "LDAP users list is set to [$GI_LDAP_USERS] - insert new or confirm existing one <ENTER>: " new_ldap_users
                if [[ $new_ldap_users != '' ]]
                then
                        ldap_users=$new_ldap_users
                fi
        else
                while [[ $ldap_users == '' ]]
                do
                        read -p "Insert insert comma separated list of user names to create them in LDAP (i.e. user1,user2,user2): " ldap_users
                done
        fi
        if [[ -z "$ldap_users" ]]
        then
                echo export GI_LDAP_USERS=$GI_LDAP_USERS >> $file
        else
                echo export GI_LDAP_USERS=$ldap_users >> $file
        fi
        while [[ $ldap_password == '' ]]
        do
                read -sp "Insert password for LDAP users: " ldap_password
                echo -e '\n'
        done
        echo "export GI_LDAP_USERS_PWD='$ldap_password'" >> $file
fi
# Configure bastion to use proxy
if [[ $use_proxy == 'P' ]]
then
        while [[ $proxy_ip == '' ]]
        do
                read -p "HTTP Proxy ip address: " proxy_ip
        done
        while [[ $proxy_port == '' ]]
        do
                read -p "HTTP Proxy port: " proxy_port
        done
        read -p "Insert comma separated list of CIDRs (like 192.168.0.0/24) which should not be proxed (do not need provide here cluster addresses): " no_proxy_add
        no_proxy="127.0.0.1,*.apps.$ocp_domain,*.$ocp_domain,$no_proxy_add"
        echo "Your proxy settings are:"
        echo "Proxy URL: http://$proxy_ip:$proxy_port"
        echo "OCP domain $ocp_domain"
        echo "Setting your HTTP proxy environment on bastion"
        echo "- Modyfying /etc/profile"
	cp -f /etc/profile /etc/profile.gi_no_proxy
        if [[ `cat /etc/profile | grep "export http_proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^export http_proxy=.*/export http_proxy=\"http:\/\/$proxy_ip:$proxy_port\"/g" /etc/profile
        else
                echo "export http_proxy=\"http://$proxy_ip:$proxy_port\"" >> /etc/profile
        fi
        if [[ `cat /etc/profile | grep "export https_proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^export https_proxy=.*/export https_proxy=\"http:\/\/$proxy_ip:$proxy_port\"/g" /etc/profile
        else
                echo "export https_proxy=\"http://$proxy_ip:$proxy_port\"" >> /etc/profile
        fi
        if [[ `cat /etc/profile | grep "export ftp_proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^export ftp_proxy=.*/export ftp_proxy=\"$proxy_ip:$proxy_port\"/g" /etc/profile
        else
                echo "export ftp_proxy=\"$proxy_ip:$proxy_port\"" >> /etc/profile
        fi
        if [[ `cat /etc/profile | grep "export no_proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^export no_proxy=.*/export no_proxy=\"$no_proxy\"/g" /etc/profile
        else
                echo "export no_proxy=\"$no_proxy\"" >> /etc/profile
        fi
        echo "- Add proxy settings to DNF config file"
	cp -f /etc/dnf/dnf.conf /etc/dnf/dnf.conf.gi_no_proxy
        if [[ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^proxy=.*/proxy=http:\/\/$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
        else
                echo "proxy=http://$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf
        fi
else
	if [[ -f /etc/profile.gi_no_proxy ]]
	then
		mv -f /etc/profile.gi_no_proxy /etc/profile
	fi
	if [[ -f /etc/dnf/dnf.conf.gi_no_proxy ]]
	then
		mv -f /etc/dnf/dnf.conf.gi_no_proxy /etc/dnf/dnf.conf
	fi
fi
if [[ $use_proxy == 'P' ]]
then
        echo "export GI_NOPROXY_NET=$no_proxy" >> $file
        echo "export GI_PROXY_URL=$proxy_ip:$proxy_port" >> $file
else
        echo "export GI_PROXY_URL=NO_PROXY" >> $file
fi
# Install software on OS in non-airgapped env
if [[ $use_air_gap == 'N' ]]
then
        echo "*** Update Fedora ***"
        dnf -qy update
        echo "*** Installing Ansible and other Fedora packages ***"
        dnf -qy install tar ansible haproxy openldap perl podman-docker ipxe-bootimgs chrony dnsmasq unzip wget jq httpd-tools policycoreutils-python-utils python3-ldap openldap-servers openldap-clients pip
        dnf -qy install ansible skopeo
        if [[ $use_proxy == 'D' ]]
        then
                pip3 install passlib
                pip3 install dnspython
		pip3 install beautifulsoup4
        else
                pip3 install passlib --proxy http://$proxy_ip:$proxy_port
                pip3 install dnspython --proxy http://$proxy_ip:$proxy_port
		pip3 install beautifulsoup4 --proxy http://$proxy_ip:$proxy_port
        fi
        # Configure Ansible
        mkdir -p /etc/ansible
        if [[ $use_proxy == 'P' ]]
        then
                echo -e "[bastion]\n127.0.0.1 \"http_proxy=http://$proxy_ip:$proxy_port\" https_proxy=\"http://$proxy_ip:$proxy_port\" ansible_connection=local" > /etc/ansible/hosts
        elif [[ $use_proxy == 'D' ]]
        then
                echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
        fi
	# Save pull secret in separate file
	if [ $use_air_gap == 'N' ]
	then
        	echo "pullSecret: '$rhn_secret'" > scripts/pull_secret.tmp
	fi
fi
# Prepare for air-gapp installation
if [[ $use_air_gap == 'Y' ]]
then
	if [[ `dnf list tar --installed 2>/dev/null|tail -n1|wc -l` -eq 0 ]]
	then
        	echo "You do not have tar tool installed!."
        	echo "Execute 'scripts/install-tar.sh' and restart init.sh"
        	exit 1
	fi
        gi_archives=''
        while [[ $gi_archives == '' ]]
        do
                printf "Where are located the offline archives? - default value is download subdirectory in the current folder or insert full path to directory: "
                read gi_archives
                gi_archives=${gi_archives:-$GI_HOME/download}
                if [[ ! -d $gi_archives ]]
                then
                        echo "Directory does not exist!"
                        gi_archives=''
                fi
        done
        echo "Offline archives located in $gi_archives - progressing ..."
        echo export GI_ARCHIVES_DIR=${gi_archives} >> $file
        echo "*** Check OS files archive existence ***"
        if [[ `ls $gi_archives/os*.tar 2>/dev/null|wc -l` -ne 1 ]]
        then
                echo "You did not upload os-<version>.tar to $gi_archives directory on bastion"
                exit 1
        fi
        echo "*** Checking source and target kernel ***"
	tar -C $GI_TEMP -xf ${gi_archives}/os*.tar kernel.txt ansible/* galaxy/* os-packages/* os-updates/*
        if [[ `uname -r` != `cat $GI_TEMP/kernel.txt` ]]
        then
                echo "Kernel of air-gap bastion differs from air-gap file generator!"
                read -p "Have you updated system before, would you like to continue (Y/N)?: " is_updated
                if [ $is_updated != 'N' ]
                then
                        echo "Upload air-gap files corresponding to bastion kernel or generate files for bastion environment."
                        exit 1
                fi
        fi
	rm -f $GI_TEMP/kernel.txt
        # Install software for air-gap installation
        echo "*** Installing OS updates ***"
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os-updates/*rpm --allowerasing
        rm -rf ${GI_TEMP}/os-updates
        echo "*** Installing OS packages ***"
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os-packages/*rpm --allowerasing
        rm -rf ${GI_TEMP}/os-packages
        echo "*** Installing Ansible and python modules ***"
        cd ${GI_TEMP}/ansible
        pip3 install passlib-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install dnspython-* --no-index --find-links '.' > /dev/null 2>&1
        cd $GI_HOME
        rm -rf ${GI_TEMP}/ansible
        cd ${GI_TEMP}/galaxy
        ansible-galaxy collection install community-general-3.3.2.tar.gz
        cd $GI_HOME
        rm -rf ${GI_TEMP}/galaxy
        # Configure Ansible
        mkdir -p /etc/ansible
        echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
        rm -rf $GI_TEMP/*
        echo "*** OS software update and installation successfully finished ***"
	if [[ ! -z "$GI_REPO_USER" ]]
        then
                read -p "Bastion image repository account name is set to [$GI_REPO_USER] - insert new or confirm existing one <ENTER>: " new_repo_admin
                if [[ $new_repo_admin != '' ]]
                then
                        repo_admin=$new_repo_admin
                fi
        else
                while [[ $repo_admin == '' ]]
                do
                        read -p "Insert new bastion image repository admin account name [admin]: " repo_admin
                        repo_admin=${repo_admin:-admin}
                done
        fi
        if [[ -z "$repo_admin" ]]
        then
                echo export GI_REPO_USER=$GI_REPO_USER >> $file
        else
                echo export GI_REPO_USER=$repo_admin >> $file
        fi
        while [[ $repo_password == '' ]]
        do
                read -sp "Insert new bastion image repository $repo_admin password: " repo_password
                echo -e '\n'
        done
        echo "export GI_REPO_USER_PWD='$repo_password'" >> $file
fi
# Create cluster ssh-key
echo "*** Add a new RSA SSH key ***"
cluster_id=`mktemp -u -p ~/.ssh/ cluster_id_rsa.XXXXXXXXXXXX`
echo "*** Cluster key: ~/.ssh/${cluster_id}, public key: ~/.ssh/${cluster_id}.pub ***"
ssh-keygen -N '' -f ${cluster_id} -q <<< y > /dev/null
echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > ~/.ssh/config
cat ${cluster_id}.pub >> /root/.ssh/authorized_keys
# Copy ssh public key to variable
echo "export GI_SSH_KEY=${cluster_id}" >> $file
# Set KUBECONFIG
echo "export KUBECONFIG=$GI_HOME/ocp/auth/kubeconfig" >> $file
# Display information
echo "Save SSH keys names: ${cluster_id} and ${cluster_id}.pub, each init.sh execution create new with random name"
echo "*** Execute commands below ***"
if [[ $use_proxy == 'P' ]]
then
        echo "- import PROXY settings: \". /etc/profile\""
fi
echo "- import variables: \". $file\""
echo "- start first playbook: \"ansible-playbook playbooks/01-finalize-bastion-setup.yaml\""
