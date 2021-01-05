#!/bin/bash

# Guardium Insights 2.5 installation automation


GI_HOME=`pwd`
file=variables.sh
echo "*** Checking CentOS version ***"
if [ `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1":"$3}'` != 'CentOS:8' ]
then
	echo "*** ERROR ***"
        echo "Your bastion machine is not CentOS 8 - please use the supported Operating System"
	exit 1
fi
echo "*** Openshift cluster architecture ***"
while ! [[ $is_prod == 'Y' || $is_prod == 'N' ]] # While string is different or empty...
do
        printf "Is your installation the production one? (\e[4mN\e[0m)o/(Y)es: "
        read is_prod
        is_prod=${is_prod:-N}
        if ! [[ $is_prod == 'Y' || $is_prod == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
if [ $is_prod == 'N' ]
then
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
else
	m_number=3
	is_onenode='N'
fi
if [ $is_onenode == 'Y' ]
then
	m_number=1
fi
if [ $is_onenode == 'N' ]
then
	while ! [[ $m_number == 1 || $m_number == '3' ]]
	do
		printf "How many master nodes will you deploy? (\e[4m1\e[0m)/3: "
		read m_number
		m_number=${m_number:-1}
		if ! [[ $m_number == 1 || $m_number == 3 ]]
                then
                        echo "Incorrect value"
                fi
	done
	echo "Define number of workers"
	echo "3 - simple installation, OCS storage installed on all workers, ICP installed on one worker"
	echo "4 - simple installation, OCS storage installed on all workers, DB2 node tainted, OCP spread on not-tainted nodes"
	while ! [[ $w_number == 4 || $w_number == '3' ]]
        do
                printf "How many workers nodes will you deploy? (\e[4m3\e[0m)/4: "
                read w_number
                w_number=${w_number:-3}
                if ! [[ $w_number == 3 || $w_number == 4 ]]
                then
                        echo "Incorrect value"
                fi
        done
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
if [[ $use_air_gap == 'Y' ]]
then
	echo "***Installing tar***"
	if [[ ! -f "$GI_HOME/tar.cpio" ]]
	then
		echo "You did not upload tar.cpio on bastion"
		exit 1
	else
		mkdir temp
		cd temp
		cpio -idv < ../tar.cpio > /dev/null 2>&1
		dnf -qy --disablerepo=* localinstall *rpm
		cd ..
                rm -rf temp
	fi
	echo "***Extracting air-gapped installation files***"
	if [[ ! -f "$GI_HOME/air-gap.tar" ]]
	then
		echo "You did not upload air-gap.tar on bastion"
		exit 1
	else
		tar xf air-gap.tar
	fi
	#rm -f air-gap.tar
	echo "***Installing CentOS packages***"
	if [[ ! -f "$GI_HOME/download/air-gap/centos-packages.tar" ]]
	then
		echo "You did not upload centos-packages.tar on bastion"
		exit 1
	else
		mkdir temp
		cd temp
		tar xvf ../download/air-gap/centos-packages.tar > /dev/null
		cd centos-packages
		dnf -qy --disablerepo=* localinstall *rpm --allowerasing
		cd ../..
	fi
	echo "***Installing Ansible and python modules***"
	if [[ ! -f "$GI_HOME/download/air-gap/ansible.tar" ]]
	then
		echo "You did not upload ansible.tar on bastion"
		exit 1
	else
		cd temp
		tar xvf ../download/air-gap/ansible.tar > /dev/null
		cd ansible
		pip3 install 'ansible-2.10.1.tar.gz' --no-index --find-links '.' > /dev/null 2>&1
		pip3 install 'passlib-1.7.4-py2.py3-none-any.whl' --no-index --find-links '.' > /dev/null 2>&1
		pip3 install 'dnspython-2.0.0-py3-none-any.whl' --no-index --find-links '.' > /dev/null 2>&1
	
		cd ../..
		rm -rf temp
	fi
	echo "***Extracting playbooks***"
	if [[ ! -f "$GI_HOME/files.tar" ]]
	then
		echo "You did not upload files.tar on bastion"
		exit 1
	else
		tar xf $GI_HOME/files.tar > /dev/null
	fi
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
	while [[ $ocp_domain == '' ]]
	do
		read -p "Cluster domain (your private domain name) [ocp.io.priv]: " ocp_domain
		ocp_domain=${ocp_domain:-ocp.io.priv}
	done
	read -p "Insert comma separated list of CIDRs to be not proxed by cluster (do not need provide here cluster addresses): " no_proxy
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
	echo "*** Installing python, tar and git ***"
	dnf -qy install python3 tar git
	echo "*** Installing Ansible ***"
fi
mkdir -p /etc/ansible
if [[ $use_proxy == 'P' ]]
then
	pip3 install ansible --proxy $proxy_ip:$proxy_port > /dev/null 2>&1
	echo -e "[bastion]\n127.0.0.1 \"http_proxy=http://$proxy_ip:$proxy_port\" https_proxy=\"http://$proxy_ip:$proxy_port\" ansible_connection=local" > /etc/ansible/hosts
else
	pip3 install ansible > /dev/null 2>&1
	echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
fi
echo "*** Add a new RSA SSH key ***"
ssh-keygen -N '' -f /root/.ssh/id_rsa -q <<< y > /dev/null
echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > /root/.ssh/config 
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
#if [[ $use_air_gap == 'N' ]]
#then
#	echo "*** Download playbooks ***"
#	mkdir -p download
#	ansible -i /etc/ansible/hosts bastion -m get_url -a "url=https://ibm.box.com/shared/static/nqjdv31pt9chna37729gwwpq39dz0rcm dest=./files.tar use_proxy=yes" > /dev/null
#fi
#tar xvf files.tar > /dev/null
#rm -f files.tar
if [[ $use_air_gap == 'N' ]]
then
	echo "*** Checking CentOS installed environment groups ***"
	if [[ `dnf group list installed|wc -l` -lt 2 || `dnf group list installed|tail -n 1|tr -d " "` != "MinimalInstall" ]]
	then
		echo "*** ERROR ***"
		echo "Your bastion machine must have installed only Minimal Install environment group"
		exit 1
	fi
fi
echo "*** Setting GI installation parameters**"
echo "# Guardium Insights installation parameters" > $file
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
if [[ ! -z "$GI_BASTION_IP" ]]
then
	read -p "Bastion IP is set to [$GI_BASTION_IP] - insert new or confirm existing one <ENTER>: " new_bastion_ip
	if [[ $new_bastion_ip != '' ]]
	then
		bastion_ip=$new_bastion_ip
	fi
else
	while [[ $bastion_ip = '' ]]
	do
		read -p "Insert Bastion IP used to communicate with Bootstrap server: " bastion_ip
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
if [ $is_onenode == 'N' ]
then
	declare -a worker_ip_arr
	while [[ $w_number != ${#worker_ip_arr[@]} ]]
	do
		if [ ! -z "$GI_WORKER_IP" ]
		then
			read -p "Current list of worker nodes IP list is set to [$GI_NODE_IP] - insert $w_number IP's (comma separated) or confirm existing <ENTER>: " new_worker_ip
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
fi
if [ $is_onenode == 'N' ]
then
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
fi
if [ $is_onenode == 'N' ]
then
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
        read -p "Bootstrap and cluster node root disk device is set to [$GI_BOOT_DEVICE] - insert new or confirm existing one <ENTER>: " new_machine_disk
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
#if [[ ! -z "$GI_NFS_DISK" ]]
#then
#	read -p "NFS disk device on bastion is set to [$GI_NFS_DISK] - insert new or confirm existing one <ENTER>: " new_nfs_disk
#        if [[ $new_nfs_disk != '' ]]
#        then
#                nfs_disk=$new_nfs_disk
#        fi
#else
#	while [[ $nfs_disk == '' ]]
#	do
#		read -p "Insert disk device used on bastion for NFS (for example sdb or nvme1n1): " nfs_disk
#	done
#fi
#if [[ -z "$nfs_disk" ]]
#then
#	echo export GI_NFS_DISK=$GI_NFS_DISK >> $file
#else
#        echo export GI_NFS_DISK=$nfs_disk >> $file
#fi
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
#if [[ ! -z "$GI_ICSADMIN" ]]
#then
#	read -p "Guardium Insights admin account name is set to [$GI_ICSADMIN] - insert new or confirm existing one <ENTER>: " new_ics_admin
#        if [[ $new_ics_admin != '' ]]
#        then
#                ics_admin=$new_ics_admin
#        fi
#else
#	while [[ $ics_admin = '' ]]
#	do
#		read -p "Insert Guardium Insights admin account name [admin]: " ics_admin
#		ics_admin=${ics_admin:-admin}
#	done
#fi
#if [[ -z "$ics_admin" ]]
#then
#	echo export GI_ICSADMIN=$GI_ICSADMIN >> $file
#else
#        echo export GI_ICSADMIN=$ics_admin >> $file
#fi
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
if [[ -z "hs_size" ]]
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
echo "pullSecret: '$rhn_secret'" > scripts/pull_secret.tmp
echo "export GI_SSH_KEY='`cat /root/.ssh/id_rsa.pub`'" >> $file
echo "export KUBECONFIG=$GI_HOME/ocp/auth/kubeconfig" >> $file
echo "*** Execute commands below ***"
if [[ $use_proxy == 'P' ]]
then
	echo "export GI_NOPROXY_NET=$no_proxy" >> $file
	echo "export GI_PROXY_URL=$proxy_ip:$proxy_port" >> $file
	echo "import PROXY settings: . /etc/profile"
else
	echo "export GI_PROXY_URL=NO_PROXY" >> $file

fi
echo "export GI_AIR_GAPPED=$use_air_gap" >> $file
echo "import variables: . $file"
echo "start first playbook: ansible-playbook playbooks/01-update-system.yaml"
