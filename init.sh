#!/bin/bash

GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
mkdir -p $GI_TEMP
file=variables.sh

echo "# Guardium Insights installation parameters" > $file

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
	else
        	echo export GI_DOMAIN=$ocp_domain >> $file
	fi
}

# Get OCP release to install
while [[ $ocp_release_decision != 'E' && $ocp_release_decision != 'S' ]]
do	
	printf "Would you provide exact version OC to install [E] or use the latest stable (S)? (\e[4mE\e[0m)xact/(S)table: "
	read ocp_release_decision
	ocp_release_decision=${ocp_release_decision:-E}
	if [[ $ocp_release_decision == 'E' ]]
	then
		while [[ $ocp_release == '' ]]
		do
			read -p "Insert OCP version to install: " ocp_release
			if [[ `echo $ocp_release|cut -f -2 -d .` != "4.6" && `echo $ocp_release|cut -f -2 -d .` != "4.7" ]]
			then
				ocp_release=''
			fi
		done
	elif [[ $ocp_release_decision == 'S' ]]
	then
		while [[ $ocp_release_stable != '6' && $ocp_release_stable != '7' ]]
		do
			printf "Would you like install the latest stable OCP release 4.(\e[4m6\e[0m)/4.(7): "
			read ocp_release_stable
			ocp_release_stable=${ocp_release_stable:-6}
			if [ $ocp_release_stable == '6' ]
			then
				ocp_release='4.6.latest'
			elif [ $ocp_release_stable == '7' ]
			then
				ocp_release='4.7.latest'
			fi
		done
	fi
done
echo "export GI_OCP_RELEASE=$ocp_release" >> $file
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
# Configure bastion to use proxy
if [[ $use_proxy == 'P' ]]
then
	get_ocp_domain
        while [[ $proxy_ip == '' ]]
        do
                read -p "HTTP Proxy ip address: " proxy_ip
        done
        while [[ $proxy_port == '' ]]
        do
                read -p "HTTP Proxy port: " proxy_port
        done
	read -p "Insert comma separated list of CIDRs (like 192.168.0.0/24) which should not be proxed (do not need provide here cluster addresses): " no_proxy
        echo "Your proxy settings are:"
        echo "Proxy URL: http://$proxy_ip:$proxy_port"
        echo "OCP domain $ocp_domain"
        echo "Setting your HTTP proxy environment on bastion"
        echo "- Modyfying /etc/profile"
        if [ `cat /etc/profile | grep "export http_proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^export http_proxy=.*/export http_proxy=\"$proxy_ip:$proxy_port\"/g" /etc/profile
        else
                echo "export http_proxy=\"$proxy_ip:$proxy_port\"" >> /etc/profile
        fi
        if [ `cat /etc/profile | grep "export https_proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^export https_proxy=.*/export https_proxy=\"$proxy_ip:$proxy_port\"/g" /etc/profile
        else
                echo "export https_proxy=\"$proxy_ip:$proxy_port\"" >> /etc/profile
        fi
        if [ `cat /etc/profile | grep "export ftp_proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^export ftp_proxy=.*/export ftp_proxy=\"$proxy_ip:$proxy_port\"/g" /etc/profile
        else
                echo "export ftp_proxy=\"$proxy_ip:$proxy_port\"" >> /etc/profile
        fi
        if [ `cat /etc/profile | grep "export no_proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^export no_proxy=.*/export no_proxy=\"127.0.0.1,localhost,*.$ocp_domain,$no_proxy\"/g" /etc/profile
        else
                echo "export no_proxy=\"127.0.0.1,localhost,*.$ocp_domain,$no_proxy\"" >> /etc/profile
        fi
        echo "- Add proxy settings to DNF config file"
        if [ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^proxy=.*/proxy=http:\/\/$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
        else
                echo "proxy=http://$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf
        fi
fi
# Check bastion OS 
echo "*** Checking OS release ***"
if [ `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1}'` != 'Fedora' ]
then
        echo "*** ERROR ***"
        echo "Your bastion machine is not Fedora OS - please use the supported Operating System"
        exit 1
else
	echo "Your system is `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1}'` - progressing ..."
fi
# Check tar availability on OS
if [ `dnf list tar --installed 2>/dev/null|tail -n1|wc -l` -eq 0 ]
then
	echo "You do not have tar tool installed!."
	echo "Execute 'scripts/install-tar.sh' and restart init.sh"
	exit 1
fi
# Unpack air-gap archives
if [[ $use_air_gap == 'Y' ]]
then
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
        echo "*** Extracting OS files ***"
        if [[ `ls $gi_archives/os*.tar|wc -l` -ne 1 ]]
        then
                echo "You did not upload os-<version>.tar to $gi_archives directory on bastion"
                exit 1
        else
                cd $gi_archives
                tar xf ${gi_archives}/os*.tar -C $GI_TEMP
                cd $GI_TEMP
	fi
	echo "*** Checking source and target kernel ***"
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
	# Install software for air-gap installation
	echo "*** Installing OS updates ***"
        tar xf ${GI_TEMP}/os-updates*.tar -C ${GI_TEMP} > /dev/null
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os-updates/*rpm --allowerasing
        rm -rf ${GI_TEMP}/os-updates
        echo "*** Installing OS packages ***"
        tar xf ${GI_TEMP}/os-packages*.tar -C ${GI_TEMP}  > /dev/null
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os-packages/*rpm --allowerasing
        rm -rf ${GI_TEMP}/os-packages
        echo "*** Installing Ansible and python modules ***"
        tar xf ${GI_TEMP}/ansible-*.tar -C ${GI_TEMP} > /dev/null
        cd ${GI_TEMP}/ansible
        pip3 install passlib-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install dnspython-* --no-index --find-links '.' > /dev/null 2>&1
	cd $GI_HOME
        rm -rf ${GI_TEMP}/ansible
        tar xf ${GI_TEMP}/galaxy-*.tar -C ${GI_TEMP} > /dev/null
	cd ${GI_TEMP}/galaxy
	ansible-galaxy collection install community-general-3.3.2.tar.gz
	cd $GI_HOME
        rm -rf ${GI_TEMP}/galaxy
	# Configure Ansible
        mkdir -p /etc/ansible
        echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
	rm -rf $GI_TEMP/*
        echo "*** OS software update and installation successfully finished ***"
fi
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
# Install software on OS
if [[ $use_air_gap == 'N' ]]
then
        echo "*** Update Fedora ***"
        dnf -qy update
        echo "*** Installing Ansible and other Fedora packages ***"
        #dnf -qy install epel-release <<< y
        dnf -qy install ansible haproxy openldap perl podman-docker ipxe-bootimgs chrony dnsmasq unzip wget jq httpd-tools policycoreutils-python-utils python3-ldap openldap-servers openldap-clients
        dnf -qy install ansible skopeo
        if [[ $use_proxy == 'D' ]]
        then
                pip3 install passlib > /dev/null 2>&1
                pip3 install dnspython > /dev/null 2>&1
        else
                pip3 install passlib --proxy $proxy_ip:$proxy_port > /dev/null 2>&1
                pip3 install dnspython --proxy $proxy_ip:$proxy_port > /dev/null 2>&1
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
fi
# Create cluster ssh-key
echo "*** Add a new RSA SSH key ***"
echo "*** Cluster key: ~/.ssh/cluster_id_rsa, public key: ~/.ssh/cluster_id_rsa.pub ***"
ssh-keygen -N '' -f ~/.ssh/cluster_id_rsa -q <<< y > /dev/null
echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > ~/.ssh/config
cat ~/.ssh/cluster_id_rsa.pub >> /root/.ssh/authorized_keys
# Collecting configuration data
echo "*** Setting GI installation parameters**"
# Get OCP domain name for non-proxy
if [[ $use_proxy != 'P' ]]
then
	get_ocp_domain
fi
# Get User/Password of portable registry on bastion
if [[ $use_air_gap == 'Y' ]]
then
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
# Define OCP architecture (one node, 3 masters, tainted OCS, tainted DB2
while ! [[ $is_onenode == 'Y' || $is_onenode == 'N' ]]
do
        printf "Is your installation the one node (allinone)? (\e[4mN\e[0m)o/(Y)es: "
        read is_onenode
        is_onenode=${is_onenode:-N}
        if ! [[ $is_onenode == 'Y' || $is_onenode == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
echo export GI_ONENODE=$is_onenode >> $file
if [[ $is_onenode == 'N' ]]
then
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
fi
# Define number of master nodes
if [ $is_onenode == 'Y' ]
then
        m_number=1
        w_number=0
else
        m_number=3
        w_number=0
fi
# Detail architecture for multinode OCP
if [[ $is_onenode == 'N' ]]
then
	# Storage type selection
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
                        read -p "Provide cluster device specification for storage virtualization (for example sdb): " storage_device
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
	if [[ $is_master_only == 'N' ]]
        then
                #while ! [[ $db2_ha == "Y" || $db2_ha == "N" ]]
                #do
                #        printf "Would you like install DB2 in HA configuration (\e[4mN\e[0m)o/(Y)es?: "
                #        read db2_ha
                #        db2_ha=${db2_ha:-N}
                #        if ! [[ $db2_ha == "Y" || $db2_ha == "N" ]]
                #        then
                #                echo "Incorrect value, insert Y or N"
                #        fi
                #done
                #if [[ $db2_ha == 'Y' ]]
                #then
                #        while [[ $db2_ha_size == "" || -z $db2_ha_size ]]
                #        do
                #                printf "How many instaces DB2 would you like to (\e[4m2\e[0m)o/(3)es?: "
                #                read db2_ha_size
                #                db2_ha_size=${db2_ha_size:-2}
                #        done
                #else
                #        db2_ha_size=1
                #fi
                #echo export GI_DB2_HA_SIZE=$db2_ha_size >> $file
                if [ $storage_type == "O" ]
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
                #while ! [[ $db2_tainted == "Y" || $db2_tainted == "N" ]]
                #do
                #        printf "Would you like isolate (taint) DB2 node/s in the OCP cluster (\e[4mN\e[0m)o/(Y)es?: "
                #        read db2_tainted
                #        db2_tainted=${db2_tainted:-N}
                #        if ! [[ $db2_tainted == "Y" || $db2_tainted == "N" ]]
                #        then
                #                echo "Incorrect value, insert Y or N"
                #        fi
                #done
        else
                #db_ha='N'
                ocs_tainted='N'
                #db_tainted='N'
                #echo export GI_DB2_HA_SIZE=0 >> $file
        fi
else
        storage_type='R'
        #db_ha='N'
        ocs_tainted='N'
        #db_tainted='N'
        #echo export GI_DB2_HA_SIZE=0 >> $file
fi
#echo export GI_STORAGE=$storage_type >> $file
#echo export GI_DB2_HA=$db2_ha >> $file
echo export GI_OCS_TAINTED=$ocs_tainted >> $file
#echo export GI_DB2_TAINTED=$db2_tainted >> $file
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
declare -a node_ip_arr
while [[ $m_number != ${#node_ip_arr[@]} ]]
do
        if [ ! -z "$GI_NODE_IP" ]
        then
                read -p "Current list of master node(s) IP is [$GI_NODE_IP] - insert $m_number IP's (comma separated) or confirm existing <ENTER>: " new_node_ip
                if [[ $new_node_ip != '' ]]
                then
                        node_ip=$new_node_ip
                else
                        node_ip=$GI_NODE_IP
                fi
        else
                read -p "Insert $m_number IP address(es) of master node(s) (comma separated): " node_ip
        fi
        IFS=',' read -r -a node_ip_arr <<< $node_ip
        GI_NODE_IP=$node_ip
done
echo export GI_NODE_IP=$node_ip >> $file
declare -a node_mac_arr
while [[ $m_number != ${#node_mac_arr[@]} ]]
do
        if [ ! -z "$GI_NODE_MAC_ADDRESS" ]
        then
                read -p "Current master node MAC address list is set to [$GI_NODE_MAC_ADDRESS] - insert $m_number MAC address(es) or confirm existing one <ENTER>: " new_node_mac
                if [[ $new_node_mac != '' ]]
                then
                        node_mac=$new_node_mac
                else
                        node_mac=$GI_NODE_MAC_ADDRESS
                fi
        else
                read -p "Insert $m_number MAC address(es) of master node(s): " node_mac
        fi
        IFS=',' read -r -a node_mac_arr <<< $node_mac
        GI_NODE_MAC_ADDRESS=$node_mac
done
echo export GI_NODE_MAC_ADDRESS=$node_mac >> $file
declare -a node_name_arr
while [[ $m_number != ${#node_name_arr[@]} ]]
do
        if [ ! -z "$GI_NODE_NAME" ]
        then
                read -p "Current master node name list is set to [$GI_NODE_NAME] - insert $m_number master name(s) or confirm existing one <ENTER>: " new_node_name
                if [[ $new_node_name != '' ]]
                then
                        node_name=$new_node_name
                else
                        node_name=$GI_NODE_NAME
                fi
        else
                read -p "Insert $m_number master node name(s): " node_name
        fi
        IFS=',' read -r -a node_name_arr <<< $node_name
        GI_NODE_NAME=$node_name
done
echo export GI_NODE_NAME=$node_name >> $file
# Defines workers, db2 and OCS nodes
if [[ $is_onenode == 'N' && $is_master_only == 'N' ]]
then
        #declare -a db_ip_arr
        #while [[ $db2_ha_size != ${#db2_ip_arr[@]} ]]
        #do
        #        if [ ! -z "$GI_DB2_IP" ]
        #        then
        #                read -p "Current list of DB2 node IP list is set to [$GI_DB2_IP] - insert $db2_ha_size IP's (comma separated) or confirm existing <ENTER>: " new_db2_ip
        #                if [[ $new_db2_ip != '' ]]
        #                then
        #                        db2_ip=$new_db2_ip
        #                else
        #                        db2_ip=$GI_DB2_IP
        #                fi
        #        else
        #                read -p "Insert $db2_ha_size IP address(es) of DB2 node(s) (comma separated): " db2_ip
        #        fi
        #        IFS=',' read -r -a db2_ip_arr <<< $db2_ip
        #        GI_DB2_IP=$db2_ip
        #done
        #echo export GI_DB2_IP=$db2_ip >> $file
        #declare -a db2_mac_arr
        #while [[ $db2_ha_size != ${#db2_mac_arr[@]} ]]
        #do
        #        if [ ! -z "$GI_DB2_MAC_ADDRESS" ]
        #        then
        #                read -p "Current DB2 MAC address list is set to [$GI_DB2_MAC_ADDRESS] - insert $db2_ha_size MAC address(es) or confirm existing one <ENTER>: " new_db2_mac
        #                if [[ $new_db2_mac != '' ]]
        #                then
        #                        db2_mac=$new_db2_mac
        #                else
        #                        db2_mac=$GI_DB2_MAC_ADDRESS
        #                fi
        #        else
        #                read -p "Insert $db2_ha_size MAC address(es) of DB2 node(s): " db2_mac
        #        fi
        #        IFS=',' read -r -a db2_mac_arr <<< $db2_mac
        #        GI_DB2_MAC_ADDRESS=$db2_mac
        #done
        #echo export GI_DB2_MAC_ADDRESS=$db2_mac >> $file
        #declare -a db2_name_arr
        #while [[ $db2_ha_size != ${#db2_name_arr[@]} ]]
        #do
        #        if [ ! -z "$GI_DB2_NAME" ]
        #        then
        #                read -p "Current DB2 node name list is set to [$GI_DB2_NAME] - insert $db2_ha_size node names or confirm existing one <ENTER>: " new_db2_name
        #                if [[ $new_db2_name != '' ]]
        #                then
        #                        db2_name=$new_db2_name
        #                else
        #                        db2_name=$GI_DB2_NAME
        #                fi
        #        else
        #                read -p "Insert $db2_ha_size DB2 node names: " db2_name
        #        fi
        #        IFS=',' read -r -a db2_name_arr <<< $db2_name
        #        GI_DB2_NAME=$DB2_name
        #done
	#echo export GI_DB2_NAME=$db2_name >> $file
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
        #if [[ $db2_tainted == 'Y' ]]
        #then
        #        m_worker_number=3
        #else
        if [[ ocs_tainted == 'N' ]]
        then
        	m_worker_number=3
        else
                m_worker_number=2
        fi
        #fi
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
# Gets OCP credentials created during installation (to avoid use the kubesystem account
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
	declare -a gi_versions=(3.0.0 3.0.1)
        while [[ ( -z $gi_version_selected ) || ( $gi_version_selected -lt 1 || $gi_version_selected -gt $i ) ]]
        do
	        echo "Select GI version:"
                i=1
                for gi_version in "${gi_versions[@]}"
        	do
                	echo "$i - $gi_version"
                        i=$((i+1))
                done
                read -p "Your choice?: " gi_version_selected
        done
        gi_version_selected=$(($gi_version_selected-1))
        echo "export GI_VERSION=$gi_version_selected" >> $file
	# Gets IBM Cloud Pull Secret
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
	declare -a gi_sizes=(values-poc-lite values-dev values-small)
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
	echo "export GI_INSTALL_GI=$gi_install" >> $file
	if [[ $gi_version_selected == '0' ]]
	then
		echo "export GI_ICS_VERSION=2" >> $file
	else
		echo "export GI_ICS_VERSION=4" >> $file
	fi
	echo "export GI_ICS_OPERANDS=N,N,Y,Y,N,Y,N" >> $file
	echo "export GI_ICS=Y" >> $file
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
                	db2_nodes=$new_db2_nodes
                else
                	db2_nodes=$GI_DB2_NODES
                fi
        else
        	read -p "Insert DB2 nodes list (comma separated): " db2_nodes
        fi
        echo export GI_DB2_NODES=$db2_nodes >> $file
else
	# ICS installation
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
	echo "export GI_ICS=$ics_install" >> $file
	if [[ $ics_install == 'Y' ]]
	then
	        declare -a ics_versions=(3.7.1 3.7.2 3.7.4 3.8.1 3.9.1 3.10.1)
	        while [[ ( -z $ics_version_selected ) || ( $ics_version_selected -lt 1 || $ics_version_selected -gt $i ) ]]
	        do
	                echo "Select ICS version to mirror:"
	                i=1
	                for ics_version in "${ics_versions[@]}"
	                do
	                        echo "$i - $ics_version"
	                        i=$((i+1))
	                done
	                read -p "Your choice?: " ics_version_selected
	        done
	        ics_version_selected=$(($ics_version_selected-1))
		echo "export GI_ICS_VERSION=$ics_version_selected" >> $file
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
		        printf "Would you like to install Metering operand with ICS?: (N)o/(\e[4mY\e[0m)es: "
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
		op_option=''
		while ! [[ $op_option == 'Y' || $op_option == 'N' ]]
		do
		        printf "Would you like to install ElasticSearch operand with ICS?: (N)o/(\e[4mY\e[0m)es: "
		        read op_option
		        op_option=${op_option:-Y}
		done
		ics_ops+=($op_option)
		op_option=''
		echo export GI_ICS_OPERANDS=`echo ${ics_ops[@]}|awk 'BEGIN { FS= " ";OFS="," } { $1=$1 } 1'` >> $file
	fi
fi
while ! [[ $install_ldap == 'Y' || $install_ldap == 'N' ]] # While string is different or empty...
do
        printf "Would you like install OpenLDAP as Guardium Insights identity source? (\e[4mY\e[0m)es/(N)o: "
        read install_ldap
        install_ldap=${install_ldap:-Y}
        if ! [[ $install_ldap == 'Y' || $install_ldap == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
if [ $install_ldap == 'Y' ]
then
	if [[ ! -z "$GI_LDAP_DOMAIN" ]]
	then
		read -p "LDAP organization DN is set to [$GI_LDAP_DOMAIN] - insert new or confirm existing one <ENTER>: " new_ldap_domain
	        if [[ $new_ldap_domain != '' ]]
        	then
                	ldap_domain=$new_ldap_domain
	        fi
	else
		read -p "Insert LDAP orgnization DN (for example: DC=io,DC=priv): " ldap_domain
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
# Save pull secret in separate file
if [ $use_air_gap == 'N' ]
then
        echo "pullSecret: '$rhn_secret'" > scripts/pull_secret.tmp
fi
# Copy ssh public key to variable
echo "export GI_SSH_KEY='`cat /root/.ssh/cluster_id_rsa.pub`'" >> $file
# Set KUBECONFIG
echo "export KUBECONFIG=$GI_HOME/ocp/auth/kubeconfig" >> $file
# Export proxy information
if [[ $use_proxy == 'P' ]]
then
        echo "export GI_NOPROXY_NET=$no_proxy" >> $file
        echo "export GI_PROXY_URL=$proxy_ip:$proxy_port" >> $file
else
        echo "export GI_PROXY_URL=NO_PROXY" >> $file
fi
# Disable virt services for dnsmasq (GNOME starts them)
#systemctl stop libvirtd > /dev/null 2>&1
#systemctl disable libvirtd > /dev/null 2>&1
# Display information
echo "Copy SSH keys ~/.ssh/cluster_id_rsa and ~/.ssh/cluster_id_rsa.pub, each init.sh execution replace them!!!"
echo "*** Execute commands below ***"
if [[ $use_proxy == 'P' ]]
then
	echo "- import PROXY settings: \". /etc/profile\""
fi
echo "- import variables: \". $file\""
echo "- start first playbook: \"ansible-playbook playbooks/01-finalize-bastion-setup.yaml\""

