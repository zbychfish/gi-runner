#!/bin/bash

# Guardium Insights 3.0 installation initialization

GI_HOME=`pwd`
file=variables.sh
echo "# Guardium Insights installation parameters" > $file
read -p "Insert OCP release to install in this process, it must correspond to existing one, in case of air-gapped installation ensure that image repository uploaded to bastion match OCP release (for instance 4.6.19): " ocp_release
echo "export GI_OCP_RELEASE=$ocp_release" > $file
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
echo "*** Checking CentOS version ***"
if [ `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1":"$3}'` != 'CentOS:8' ]
then
	echo "*** ERROR ***"
        echo "Your bastion machine is not CentOS 8 - please use the supported Operating System"
	exit 1
fi
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
if [[ -z "$use_air_gap" ]]
then
        echo export GI_AIR_GAPPED=$GI_AIR_GAPPED >> $file
else
        echo export GI_AIR_GAPPED=$use_air_gap >> $file
fi
if [[ $use_air_gap == 'Y' ]]
then
        echo "*** Extracting air-gapped installation files ***"
        if [[ `ls $GI_HOME/download/air-gap*.tar|wc -l` -ne 1 ]]
        then
                echo "You did not upload air-gap.tar to download directory on bastion"
                exit 1
        else
                mkdir -p air-gap
                tar xf download/air-gap*.tar -C download
		tar xf download/packages-*.tar -C air-gap
        fi
        echo "*** Installing CentOS updates ***"
        #tar xf air-gap/centos-updates*.tar -C air-gap --strip-components 1 > /dev/null
        tar xf air-gap/centos-updates*.tar -C air-gap > /dev/null
        dnf -qy --disablerepo=* localinstall air-gap/centos-updates/*rpm --allowerasing
        rm -rf air-gap/centos-updates
        echo "*** Installing CentOS packages ***"
        tar xf air-gap/centos-packages*.tar -C air-gap  > /dev/null
        dnf -qy --disablerepo=* localinstall air-gap/centos-packages/*rpm --allowerasing
        rm -rf air-gap/centos-packages
        echo "*** Installing Ansible and python modules ***"
        tar xf air-gap/ansible-*.tar -C air-gap > /dev/null
        cd air-gap/ansible
        pip3 install passlib-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install dnspython-* --no-index --find-links '.' > /dev/null 2>&1
	#ansible-galaxy collection install ansible-posix-1.1.2-dev8.tar.gz
	mkdir -p /etc/ansible
	echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
        cd $GI_HOME
        rm -rf air-gap/ansible
fi
if [[ ! -z "$GI_DOMAIN" ]]
then
        read -p "Cluster domain is set to [$GI_DOMAIN] - insert new or confirm existing one <ENTER>: " new_ocp_domain
        if [[ $new_ocp_domain != '' ]]
        then
                ocp_domain=$new_ocp_domain
        fi
else
	while [[ $ocp_domain == '' ]]
	do
		read -p "Insert cluster domain (your private domain name) [ocp.io.priv]: " ocp_domain
	        ocp_domain=${ocp_domain:-ocp.io.priv}
	done
fi
if [[ -z "$ocp_domain" ]]
then
        echo export GI_DOMAIN=$GI_DOMAIN >> $file
else
        echo export GI_DOMAIN=$ocp_domain >> $file
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
fi
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
	read -p "Insert comma separated list of CIDRs which should not be proxed (do not need provide here cluster addresses): " no_proxy
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
		sed -i "s/^export no_proxy=.*/export no_proxy=\"127.0.0.1,localhost,*.$ocp_domain\"/g" /etc/profile
	else
		echo "export no_proxy=\"127.0.0.1,localhost,*.$ocp_domain,$no_proxy\"" >> /etc/profile
	fi
	echo "- Read proxy variables into shell"
	. /etc/profile
	echo "- Add proxy settings to DNF config file"
	if [ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]
	then
		sed -i "s/^proxy=.*/proxy=$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
	else
		echo "proxy=$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf 
	fi
fi
if [[ $use_air_gap == 'N' ]]
then
        echo "*** Update CentOS ***"
        dnf -qy update
	echo "*** Installing python, tar and git ***"
	dnf -qy install python3 tar git
	echo "*** Installing Ansible ***"
fi
mkdir -p /etc/ansible
if [[ $use_proxy == 'P' ]]
then
	pip3 install ansible --proxy $proxy_ip:$proxy_port > /dev/null 2>&1
	echo -e "[bastion]\n127.0.0.1 \"http_proxy=http://$proxy_ip:$proxy_port\" https_proxy=\"http://$proxy_ip:$proxy_port\" ansible_connection=local" > /etc/ansible/hosts
elif [[ $use_proxy == 'D' ]]
then
	pip3 install ansible > /dev/null 2>&1
	echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
fi
#ansible-galaxy collection install ansible.posix
echo "*** Add a new RSA SSH key ***"
ssh-keygen -N '' -f /root/.ssh/cluster_id_rsa -q <<< y > /dev/null
echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > /root/.ssh/config 
cat /root/.ssh/cluster_id_rsa.pub >> /root/.ssh/authorized_keys
if [[ $use_air_gap == 'N' ]]
then
	echo "*** Checking CentOS installed environment groups ***"
	if [[ `dnf group list installed|grep "Server with GUI"|wc -l` -ne 1 ]]
	then
		echo "*** ERROR ***"
		echo "Your bastion machine must have installed Server with GUI environment group"
		exit 1
	fi
fi
echo "*** Setting GI installation parameters**"
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
        	while [[ $repo_admin = '' ]]
        	do
                	read -p "Insert bastion image repo admin account name [admin]: " repo_admin
                	repo_admin=${repo_admin:-admin}
        	done
	fi
	if [[ -z "$repo_admin" ]]
	then
        	echo export GI_REPO_USER=$GI_REPO_USER >> $file
	else
        	echo export GI_REPO_USER=$repo_admin >> $file
	fi
	while [[ $repo_password = '' ]]
	do
        	read -sp "Insert bastion image repository $repo_admin password: " repo_password
	        echo -e '\n'
	done
	echo "export GI_REPO_USER_PWD='$repo_password'" >> $file
fi
echo "*** Openshift cluster architecture ***"
while ! [[ $is_onenode == 'Y' || $is_onenode == 'N' ]]
do
	printf "Is your installation the one node (allinone)? (\e[4mY\e[0m)es/(N)o: "
	read is_onenode
        is_onenode=${is_onenode:-Y}
       	if ! [[ $is_onenode == 'Y' || $is_onenode == 'N' ]]
        then
       	        echo "Incorrect value"
        fi
done
echo export GI_ONENODE=$is_onenode >> $file
while ! [[ $is_master_only == 'Y' || $is_master_only == 'N' ]]
do
        printf "Is your installation the 3 nodes only (master only)? (\e[4mY\e[0m)es/(N)o: "
        read is_master_only
        is_master_only=${is_master_only:-Y}
        if ! [[ $is_master_only == 'Y' || $is_master_only == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
echo export GI_MASTER_ONLY=$is_master_only >> $file
if [ $is_onenode == 'Y' ]
then
	m_number=1
	w_number=0
else
	m_number=3
	w_number=0
fi
if [[ $is_onenode == 'N' ]]
then
	storage_type='O'
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
		while ! [[ $db2_ha == "Y" || $db2_ha == "N" ]]
		do
			printf "Would you like install DB2 in HA configuration (\e[4mN\e[0m)o/(Y)es?: "
			read db2_ha
			db2_ha=${db2_ha:-N}
			if ! [[ $db2_ha == "Y" || $db2_ha == "N" ]]
			then
				echo "Incorrect value, insert Y or N"
			fi
		done
		if [[ $db2_ha == 'Y' ]]
		then
			while [[ $db2_ha_size == "" || -z $db2_ha_size ]]
	        	do
        	        	printf "How many instaces DB2 would you like to (\e[4m2\e[0m)o/(3)es?: "
	                	read db2_ha_size
	                	db2_ha_size=${db2_ha_size:-2}
	        	done
		else
			db2_ha_size=1
		fi
		echo export GI_DB2_HA_SIZE=$db2_ha_size >> $file
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
		while ! [[ $db2_tainted == "Y" || $db2_tainted == "N" ]]
		do
			printf "Would you like isolate (taint) DB2 node/s in the OCP cluster (\e[4mN\e[0m)o/(Y)es?: "
			read db2_tainted
			db2_tainted=${db2_tainted:-N}
			if ! [[ $db2_tainted == "Y" || $db2_tainted == "N" ]]
			then
				echo "Incorrect value, insert Y or N"
			fi
		done
	else
		db_ha='N'
        	ocs_tainted='N'
        	db_tainted='N'
		echo export GI_DB2_HA_SIZE=0 >> $file
	fi
else
	storage_type='R'
	db_ha='N'
	ocs_tainted='N'
	db_tainted='N'
	echo export GI_DB2_HA_SIZE=0 >> $file
fi
echo export GI_STORAGE=$storage_type >> $file
echo export GI_DB2_HA=$db2_ha >> $file
echo export GI_OCS_TAINTED=$ocs_tainted >> $file
echo export GI_DB2_TAINTED=$db2_tainted >> $file
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
                fi
        else
                while [[ $ntp_server == '' ]]
                do
                        read -p "Insert NTP server IP address: " ntp_server
                done
        fi
fi
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
		read -p "Point DNS server to resolve public names: " dns_forwarding
	done
fi
if [[ -z "$dns_forwarding" ]]
then
	echo export GI_DNS_FORWARDER=$GI_DNS_FORWARDER >> $file
else
	echo export GI_DNS_FORWARDER=$dns_forwarding >> $file
fi
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
if [[ $is_onenode == 'N' && $is_master_only == 'N' ]]
then
	declare -a db_ip_arr
	while [[ $db2_ha_size != ${#db2_ip_arr[@]} ]]
	do
		if [ ! -z "$GI_DB2_IP" ]
	        then
        	        read -p "Current list of DB2 node IP list is set to [$GI_DB2_IP] - insert $db2_ha_size IP's (comma separated) or confirm existing <ENTER>: " new_db2_ip
	                if [[ $new_db2_ip != '' ]]
        	        then
                	        db2_ip=$new_db2_ip
	                else
        	                db2_ip=$GI_DB2_IP
	                fi
	        else
                	read -p "Insert $db2_ha_size IP address(es) of DB2 node(s) (comma separated): " db2_ip
	        fi
        	IFS=',' read -r -a db2_ip_arr <<< $db2_ip
	        GI_DB2_IP=$db2_ip
	done
	echo export GI_DB2_IP=$db2_ip >> $file
	declare -a db2_mac_arr
	while [[ $db2_ha_size != ${#db2_mac_arr[@]} ]]
	do
        	if [ ! -z "$GI_DB2_MAC_ADDRESS" ]
	        then
        	        read -p "Current DB2 MAC address list is set to [$GI_DB2_MAC_ADDRESS] - insert $db2_ha_size MAC address(es) or confirm existing one <ENTER>: " new_db2_mac
                	if [[ $new_db2_mac != '' ]]
	                then
        	                db2_mac=$new_db2_mac
	                else
	                        db2_mac=$GI_DB2_MAC_ADDRESS
        	        fi
	        else
        	        read -p "Insert $db2_ha_size MAC address(es) of DB2 node(s): " db2_mac
	        fi
	        IFS=',' read -r -a db2_mac_arr <<< $db2_mac
	        GI_DB2_MAC_ADDRESS=$db2_mac
	done
	echo export GI_DB2_MAC_ADDRESS=$db2_mac >> $file
	declare -a db2_name_arr
        while [[ $db2_ha_size != ${#db2_name_arr[@]} ]]
        do
                if [ ! -z "$GI_DB2_NAME" ]
                then
                        read -p "Current DB2 node name list is set to [$GI_DB2_NAME] - insert $db2_ha_size node names or confirm existing one <ENTER>: " new_db2_name
                        if [[ $new_db2_name != '' ]]
                        then
                                db2_name=$new_db2_name
                        else
                                db2_name=$GI_DB2_NAME
                        fi
                else
                        read -p "Insert $db2_ha_size DB2 node names: " db2_name
                fi
                IFS=',' read -r -a db2_name_arr <<< $db2_name
                GI_DB2_NAME=$DB2_name
        done
        echo export GI_DB2_NAME=$db2_name >> $file
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
	if [[ $db2_tainted == 'Y' ]]
	then
		m_worker_number=3
	else
		if [[ ocs_tainted == 'N' ]]
		then
			m_worker_number=3
		else
			m_worker_number=2
		fi
	fi
	echo "Define number of workers, you must set minimum $m_worker_number of workers."
	while ! [[ $w_number -ge $m_worker_number ]]
        do
		
                printf "How many workers the additional workers will you deploy [$m_worker_number]?: "
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
if [[ ! -z "$GI_BASTION_INTERFACE" ]]
then
        read -p "Bootstrap and cluster node booting NIC device is set to [$GI_BASTION_INTERFACE] - insert new or confirm existing one <ENTER>: " new_machine_nic
        if [[ $new_machine_nic != '' ]]
        then
                machine_nic=$new_machine_nic
        fi
else
	while [[ $machine_nic == '' ]]
	do
		read -p "Provide bootstrap and cluster node booting NIC device (for instance ens192): " machine_nic
	done
fi
if [[ -z "$machine_nic" ]]
then
        echo export GI_BASTION_INTERFACE=$GI_BASTION_INTERFACE >> $file
else
        echo export GI_BASTION_INTERFACE=$machine_nic >> $file
fi
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
		read -p "Provide bootstrap and cluster node root disk device for Core OS installation (for instance sdb or nvme0n1): " machine_disk
	done
fi
if [[ -z "$machine_disk" ]]
then
        echo export GI_BOOT_DEVICE=$GI_BOOT_DEVICE >> $file
else
        echo export GI_BOOT_DEVICE=$machine_disk >> $file
fi
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
	if [[ ! -z "$GI_IBMCLOUD_KEY" ]]
	then
		read -p "IBM Cloud key is set to [$GI_IBMCLOUD_KEY] - insert new or confirm existing one <ENTER>: " new_cloud_key
        	if [[ $new_cloud_key != '' ]]
	        then
        	        cloud_key=$new_cloud_key
	        fi
	else
		while [[ $cloud_key == '' ]]
		do
			read -p "Insert IBM Cloud key (use this link to get access to it https://myibm.ibm.com/products-services/containerlibrary): " cloud_key
		done
	fi
	if [[ -z "$cloud_key" ]]
	then
		echo "export GI_IBMCLOUD_KEY='$GI_IBMCLOUD_KEY'" >> $file
	else
	        echo "export GI_IBMCLOUD_KEY='$cloud_key'" >> $file
	fi
fi
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
		read -p "Insert OpenShift admin account name [ocadmin]: " ocp_admin
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
	read -sp "Insert OpenShift $ocp_admin password: " ocp_password
	echo -e '\n'
done
echo "export GI_OCADMIN_PWD='$ocp_password'" >> $file
while [[ $ics_password == '' ]]
do
	read -sp "Insert IBM Common Services admin user password: " ics_password
	echo -e '\n'
done
echo "export GI_ICSADMIN_PWD='$ics_password'" >> $file
if [[ ! -z "$GI_HS_SIZE" ]]
then
       read -p "Guardium Insights hot storage size is set to [$GI_HS_SIZE] - insert new size or confirm existing one <ENTER>: " new_hs_size
        if [[ $new_hs_size != '' ]]
        then
                hs_size=$new_hs_size
        fi
else
       while [[ $hs_size == '' ]]
       do
               read -p "Insert Guardium Insights hot storage size (default size 300 gigabytes) [300]: " hs_size
               hs_size=${hs_size:-300}
       done
fi
if [[ -z $hs_size ]]
then
       echo export GI_HS_SIZE=$GI_HS_SIZE >> $file
else
       echo export GI_HS_SIZE=$hs_size >> $file
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
if [ $use_air_gap == 'N' ]
then
	echo "pullSecret: '$rhn_secret'" > scripts/pull_secret.tmp
fi
echo "export GI_SSH_KEY='`cat /root/.ssh/cluster_id_rsa.pub`'" >> $file
echo "export KUBECONFIG=$GI_HOME/ocp/auth/kubeconfig" >> $file
echo "*** Execute commands below ***"
if [[ $use_proxy == 'P' ]]
then
	echo "export GI_NOPROXY_NET=$no_proxy" >> $file
	echo "export GI_PROXY_URL=$proxy_ip:$proxy_port" >> $file
	echo "- import PROXY settings: \". /etc/profile\""
else
	echo "export GI_PROXY_URL=NO_PROXY" >> $file
fi
# Disable virt services for dnsmasq (GNOME starts them)
systemctl stop libvirtd
systemctl disable libvirtd
echo "- import variables: \". $file\""
echo "- start first playbook: \"ansible-playbook playbooks/01-install-software-on-bastion.yaml\""
