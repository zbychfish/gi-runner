#!/bin/bash

#author: zibi - zszmigiero@gmail.com

#import global variables
. ./scripts/init.globals.sh
function msg() {
	$2 && printf "$1\n" || printf "$1"
}

function check_bastion_os() {
	if [[ `hostnamectl|grep "Operating System"|awk -F ':' '{print $2}'|awk '{print $1}'` != 'Fedora' ]]
		then
        	msg "*** ERROR ***" true
        	msg "Your bastion machine is not Fedora OS - please use the supported Operating System" true
        	exit 1
	else
        	msg "You use `hostnamectl|grep "Operating System"` - tested releases $fedora_supp_releases" true
	fi
}

function display_list () {
	local list=("$@")
	local i=1
        for element in "${list[@]}"
        do
		if [[ $i -eq ${#list[@]} ]]
		then
 			msg "\e[4m$i - $element\e[0m" true
		else
			msg "$i - $element" true
		fi
        	i=$((i+1))
        done
}

function get_input() {
	unset input_variable
	msg "$2" false
	case $1 in
		"yn")
			$3 && msg "(\e[4mN\e[0m)o/(Y)es: " false || msg "(N)o/(\e[4mY\e[0m)es: " false
			read input_variable
			$3 && input_variable=${input_variable:-N} || input_variable=${input_variable:-Y}
			;;
		"dp")
                        read input_variable
                        $3 && input_variable=${input_variable:-D} || input_variable=${input_variable:-P}
			;;
		"cs")
                        read input_variable
                        $3 && input_variable=${input_variable:-C} || input_variable=${input_variable:-S}
			;;
		"list")
			msg "" true
			shift
			shift
			local list=("$@")
			display_list $@
			msg "Your choice: " false
			read input_variable
			input_variable=${input_variable:-${#list[@]}}
			;;
		"es")
                        read input_variable
                        $3 && input_variable=${input_variable:-S} || input_variable=${input_variable:-E}
                        ;;
		"int")
			read input_variable
			;;
		"sto")
                        read input_variable
                        $3 && input_variable=${input_variable:-R} || input_variable=${input_variable:-O}
                        ;;
		"txt")
			read input_variable
			if $3
			then
				[ -z ${input_variable} ] && input_variable="$4"
			fi
			;;
		"pwd")
			local password
			local password2
			echo
			while true; do
  				read -s -p "Password: " password
				echo
				if $3
				then
					password="$4"
					password2="$4"
				else
  					read -s -p "Password (again): " password2
  					echo
				fi
  				[ "$password" = "$password2" ] && break
  				echo "Please try again"
			done
			input_variable="$password"
			;;
		"*")
			exit 1
			;;
	esac
}

function check_input() {
	case $2 in
		"yn")
			[[ $1 == 'N' || $1 == 'Y' ]] && echo false || echo true
			;;
		"dp")   
			[[ $1 == 'D' || $1 == 'P' ]] && echo false || echo true
			;;
		"cs")   
			[[ $1 == 'C' || $1 == 'S' ]] && echo false || echo true
			;;
		"list")
			if [[ $1 == +([[:digit:]]) ]]
			then
				[[ $1 -gt 0 && $1 -le $3 ]] && echo false || echo true 
			else
				echo true
			fi
			;;
		"es")
			[[ $1 == 'E' || $1 == 'S' ]] && echo false || echo true
			;;
		"int")
			if [[ $1 == +([[:digit:]]) ]]
			then
				[[ $1 -ge $3 && $1 -le $4 ]] && echo false || echo true
			else
				echo true
			fi
			;;
		"sto")
			[[ $1 == 'O' || $1 == 'R' ]] && echo false || echo true
                        ;;
		"ip")
			local ip
    			if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    			then
				IFS='.' read -r -a ip <<< $1
		        	[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]] 
        			[[ $? -eq 0 ]] && echo false || echo true
			else 
				echo true
			fi
			;;
		"txt")
			case $3 in
				"1")
					[[ $1 =~ ^[a-zA-Z][a-zA-Z0-9]{1,64}$ ]] && echo false || echo true
					;;
				"2")
					[[ ! -z $1 ]] && echo false || echo true
					;;
				"3")
					if [ -z "$1" ] || $(echo "$1" | egrep -q "[[:space:]]" && echo true || echo false)
					then
					       	echo true
					else
						[[ ${#1} -le $4 ]] && echo false || echo true
					fi
					;;
				"*")
					exit 1
					;;
			esac
			;;
		"domain")
			[[ $1 =~  ^([a-zA-Z0-9](([a-zA-Z0-9-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]] && echo false || echo true
			;;
		"ips")
			local ip_value
			IFS=',' read -r -a master_ip_arr <<< $1
			if [[ ${#master_ip_arr[@]} -eq $3 && $(printf '%s\n' "${master_ip_arr[@]}"|sort|uniq -d|wc -l) -eq 0 ]]
			then
				local is_wrong=false
				for ip_value in "${master_ip_arr[@]}"
				do
					$(check_input $ip_value "ip") && is_wrong=true
				done
				echo $is_wrong
			else
				echo true
			fi
			;;
		"mac")
			[[ $1 =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]] && echo false || echo true
                        ;;
		"macs")
			local mac_value
                        IFS=',' read -r -a master_mac_arr <<< $1
                        if [[ ${#master_mac_arr[@]} -eq $3 && $(printf '%s\n' "${master_mac_arr[@]}"|sort|uniq -d|wc -l) -eq 0 ]]
                        then
                                local is_wrong=false
                                for mac_value in "${master_mac_arr[@]}"
                                do
                                        $(check_input $mac_value "mac") && is_wrong=true
                                done
                                echo $is_wrong
                        else
                                echo true
                        fi
                        ;;
		"txt_list")
			local txt_value
			local txt_arr
			IFS=',' read -r -a txt_arr <<< $1
			if [[ ${#txt_arr[@]} -eq $3 ]]
                        then
                                local is_wrong=false
                                for txt_value in "${txt_arr[@]}"
                                do
                                        [[ "$txt_value" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,}[a-zA-Z0-9]$ ]] || is_wrong=true
                                done
                                echo $is_wrong
                        else
                                echo true
                        fi
                        ;;
		"tz")
			if [[ "$1" =~ ^[a-zA-Z0-9_+-]{1,}/[a-zA-Z0-9_+-]{1,}$ ]]
			then
				timedatectl set-timezone "$1" 2>/dev/null
                        	[[ $? -eq 0 ]] && echo false || echo true
			else
				echo true
			fi
			;;
		"td")
			timedatectl set-time "$1" 2>/dev/null
			[[ $? -eq 0 ]] && echo false || echo true
			;;
		"nodes")
			local element1
			local element2
			local i=0
			local node_arr
			local selected_arr
			IFS=',' read -r -a selected_arr <<< "$1"
			IFS=',' read -r -a node_arr <<< "$3"
                        if [[ $(printf '%s\n' "${selected_arr[@]}"|sort|uniq -d|wc -l) -eq 0 ]]
			then
				for element1 in ${selected_arr[@]}; do for element2 in ${node_arr[@]}; do [[ "$element1" == "$element2" ]] && i=$(($i+1));done; done
				case $5 in
					"max")
						[ $i -ge $4 ] && echo false || echo true
						;;
					"def")
						[ $4 -eq $i ] && echo false || echo true
						;;
					"*")
						exit 1
						;;
				esac
				
			else
				echo true
			fi
			;;
		"cidr")
			if [[ "$1" =~  ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$ ]]
			then
				( ! $(check_input `echo "$1"|awk -F'/' '{print $1}'` "ip") && ! $(check_input `echo "$1"|awk -F'/' '{print $2}'` "int" 8 22) ) && echo false || echo true
			else
				echo true
			fi
			;;
		"cidr_list")
			local cidr_arr
			local cidr
			if $3 && [ -z "$1" ]
			then
				echo false
			else
				if [ -z "$1" ] || $(echo "$1" | egrep -q "[[:space:]]" && echo true || echo false)
				then
					echo true
				else
					local result=false
					IFS=',' read -r -a cidr_arr <<< "$1"
					for cidr in "${cidr_arr[@]}"
					do
						check_input "$cidr" "cidr" && result=true
					done
					echo $result
				fi
			fi
                        ;;
		"jwt")
			if [ "$1" ]
			then
				{ sed 's/\./\n/g' <<< $(cut -d. -f1,2 <<< "$1")|{ base64 --decode 2>/dev/null ;}|jq . ;} 1>/dev/null
				[[ $? -eq 0 ]] && echo false || echo true
			else
				echo true
			fi
			;;
		"cert")
			if [ "$1" ]
			then
				case $3 in
					"ca")
						openssl x509 -in "$1" -text -noout &>/dev/null 
						[[ $? -eq 0 ]] && echo false || echo true
						;;
					"app")
						openssl verify -CAfile "$4" "$1" &>/dev/null
						[[ $? -eq 0 ]] && echo false || echo true
						;;
					"key")
						openssl rsa -in "$1" -check &>/dev/null
						if [[ $? -eq 0 ]]
						then
							[[ "$(openssl x509 -noout -modulus -in "$4" 2>/dev/null)" == "$(openssl rsa -noout -modulus -in "$1" 2>/dev/null)" ]] && echo false || echo true
						else
							echo true
						fi
						;;
					"*")
						exit 1
						;;
				esac
			else
				echo true
			fi
			;;
		"ldap_domain")
			if [ "$1" ]
			then
				[[ "$1" =~ ^([dD][cC]=[a-zA-Z-]{2,64},){1,}[dD][cC]=[a-zA-Z-]{2,64}$ ]] && echo false || echo true
			else
				echo true
			fi
			;;
		"users_list")
			local ulist
			if [ -z "$1" ] || $(echo "$1" | egrep -q "[[:space:]]" && echo true || echo false)
                        then
                        	echo true
                        else
				local result=false
				IFS=',' read -r -a ulist <<< "$1"
				for user in ${ulist[@]}
				do
					[[ "$user" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,}[a-zA-Z0-9]$ ]] || result=true
				done
				echo $result
			fi
			;;
		"*")
			exit 1
			;;
	esac
}

function save_variable() {
	echo "export $1=$2" >> $file
}

function switch_dnf_sync_off() {
        if [[ `grep "metadata_timer_sync=" /etc/dnf/dnf.conf|wc -l` -eq 0 ]]
        then
                echo "metadata_timer_sync=0" >> /etc/dnf/dnf.conf
        else
                sed 's/.*metadata_timer_sync=.*/metadata_timer_sync=0/' /etc/dnf/dnf.conf
        fi
}

function get_network_installation_type() {
	use_air_gap=${use_air_gap:-Z}	
	while $(check_input ${use_air_gap} "yn")
	do
		get_input "yn" "Is your environment air-gapped? - " true
		use_air_gap=${input_variable^^}
	done
	if [ $use_air_gap == 'Y' ] 
	then 
		switch_dnf_sync_off
		save_variable GI_INTERNET_ACCESS "A"
	else
		use_proxy=${use_proxy:-Z}
		while $(check_input ${use_proxy} "dp")
		do
			get_input "dp" "Has your environment direct access to the internet or use HTTP proxy? (\e[4mD\e[0m)irect/(P)roxy: " true
			use_proxy=${input_variable^^}
		done
		save_variable GI_INTERNET_ACCESS $use_proxy
	fi
}

function select_gi_version() {
	gi_version_selected=${gi_version_selected:-Z}
	while $(check_input ${gi_version_selected} "list" ${#gi_versions[@]})
	do
		get_input "list" "Select GI version: " "${gi_versions[@]}"
		gi_version_selected=$input_variable
	done
	msg "Guardium Insights installation choice assumes installation of bundled version of ICS" true
        msg " - ICS 3.7.4 for GI 3.0.0" true
        msg " - ICS 3.9.0 for GI 3.0.1" true
        msg " - ICS 3.10.0 for GI 3.0.2" true
        msg " - ICS 3.14.2 for GI 3.1.0" true
        msg "If you would like install different ICS version (supported by selected GI) please modify variable.sh file before starting playbooks" true
        msg "In case of air-gapped installation you must install the bundled ICS version" true
	gi_version_selected=$(($gi_version_selected-1))
	save_variable GI_VERSION $gi_version_selected
	ics_version_selected=${bundled_in_gi_ics_versions[$gi_version_selected]}
        ics_install='Y'
        save_variable GI_ICS_VERSION $ics_version_selected
}

function select_ics_version() {
	ics_install=${ics_install:-Z}
	while $(check_input ${ics_install} "yn")
        do
		get_input "yn" "Would you like to install Cloud Packs Foundational Services (IBM Common Services)? " false
                ics_install=${input_variable^^}
        done
	if [[ $ics_install == 'Y' ]]
	then
		ics_version_selected=${ics_version_selected:-0}
		while $(check_input ${ics_version_selected} "list" ${#ics_versions[@]})
		do
			get_input "list" "Select ICS version: " "${ics_versions[@]}"
                	ics_version_selected=$input_variable
		done
		ics_version_selected=$(($ics_version_selected-1))
        	save_variable GI_ICS_VERSION $ics_version_selected
		ics_install='Y'
	else
		ics_install='N'
	fi
}

function select_ocp_version() {
	if [[ $gi_install == 'Y' ]]
	then
        	IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_gi[$gi_version_selected]}
	elif [[ $ics_install == 'Y' ]]
	then
        	IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_ics[$ics_version_selected]}
	fi
	local new_major_versions=()
	local i=1
        for ocp_version in "${ocp_versions[@]}"
        do
		new_major_versions+=("${ocp_major_versions[$ocp_version]}")
                i=$((i+1))
        done
	ocp_major_version=${ocp_major_version:-0}
	while $(check_input ${ocp_major_version} "list" ${#ocp_versions[@]})
	do
		get_input "list" "Select OCP major version: " "${new_major_versions[@]}"
		ocp_major_version=$input_variable
	done
	for i in "${!ocp_major_versions[@]}"; do
   		[[ "${ocp_major_versions[$i]}" = "${new_major_versions[$(($ocp_major_version-1))]}" ]] && break
	done
	ocp_major_version=$i
	if [[ $use_air_gap == 'N' ]]
	then
		ocp_release_decision=${ocp_release_decision:-Z}
		while $(check_input ${ocp_release_decision} "es")
        	do
			get_input "es" "Would you provide exact version OC to install (E) or use the latest stable [S]? (E)xact/(\e[4mS\e[0m)table: " true
                	ocp_release_decision=${input_variable^^}
        	done
	else
		ocp_release_decision='E'
	fi
	if [[ $ocp_release_decision == 'E' ]]
	then
		msg "Insert minor version of OpenShift ${ocp_major_versions[${ocp_major_version}]}.x" true
		msg "It must be existing version - you can check list of available version using this URL: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_versions[${ocp_major_version}]}/latest/" true
		ocp_release_minor=${ocp_release_minor:-Z}
		while $(check_input ${ocp_release_minor} "int" 0 1000)
		do
			get_input "int" "Insert minor version of OCP ${ocp_major_versions[${ocp_major_version}]} to install (must be existing one): " false
			ocp_release_minor=${input_variable}
		done
		ocp_release="${ocp_major_versions[${ocp_major_version}]}.${ocp_release_minor}"
	else
		ocp_release="${ocp_major_versions[${ocp_major_version}]}.latest"
	fi
	save_variable GI_OCP_RELEASE $ocp_release
}

function get_software_selection() {
	gi_install=${gi_install:-Z}
	while $(check_input ${gi_install} "yn")
	do
		get_input "yn" "Would you like to install Guardium Insights? " false
		gi_install=${input_variable^^}
	done
	save_variable GI_INSTALL_GI $gi_install
	[ $gi_install == 'Y' ] && select_gi_version || select_ics_version
	save_variable GI_ICS $ics_install
	select_ocp_version
	while $(check_input ${install_ldap} "yn")
        do
                get_input "yn" "Would you like to install OpenLDAP? " false
                install_ldap=${input_variable^^}
        done
	save_variable GI_INSTALL_LDAP $install_ldap
}

function get_software_architecture() {
	msg "OCP can be installed only on 3 nodes which create control and worker plane" true
	msg "This kind of architecture has some limitations:" true
	msg " - You cannot isolate storage on separate nodes" true
	msg " - You cannot isolate GI and CPFS" true
	is_master_only=${is_master_only:-Z}
	while $(check_input ${is_master_only} "yn")
	do
		get_input "yn" "Is your installation the 3 nodes only? " true
		is_master_only=${input_variable^^}
	done
	save_variable GI_MASTER_ONLY $is_master_only
	msg "Decide what kind of cluster storage option will be implemented:" true
	msg " - OpenShift Container Storage - commercial rook-ceph branch from RedHat" true
	msg " - Rook-Ceph - opensource cluster storage option" true
	storage_type=${storage_type:-Z}
	while $(check_input ${storage_type} "sto")
        do
		get_input "sto" "Choice the cluster storage type? (O)CS/(\e[4mR\e[0m)ook: " true
                storage_type=${input_variable^^}
        done
        save_variable GI_STORAGE_TYPE $storage_type
	if [[ $storage_type == "O" && $is_master_only == 'N' ]]
	then
		msg "OCS tainting will require minimum 3 additional workers in your cluster to manage cluster storage"
		ocs_tainted=${ocs_tainted:-Z}
		while $(check_input ${ocs_tainted} "yn")
		do
			get_input "yn" "Should be OCS tainted? " true
			ocs_tainted=${input_variable^^}
		done
		save_variable GI_OCS_TAINTED $ocs_tainted
	else
		save_variable GI_OCS_TAINTED "N"
	fi
	if [[ $gi_install == "Y" ]]
	then
		gi_size_selected=${gi_size_selected:-0}
	        while $(check_input ${gi_size_selected} "list" ${#gi_sizes[@]})
        	do
                	get_input "list" "Select Guardium Insights deployment template: " "${gi_sizes[@]}"
			gi_size_selected=$input_variable
        	done
		gi_size="${gi_sizes[$((${gi_size_selected} - 1))]}"
		save_variable GI_SIZE_GI $gi_size
	fi
	if [[ $gi_install == "Y" && $is_master_only == 'N' ]]
	then
		msg "DB2 tainting will require additional workers in your cluster to manage Guardium Insights database backend"
                db2_tainted=${db2_tainted:-Z}
                while $(check_input ${db2_tainted} "yn")
                do
                        get_input "yn" "Should be DB2 tainted? " true
                        db2_tainted=${input_variable^^}
                done
                save_variable GI_DB2_TAINTED $db2_tainted
	fi
}

function get_bastion_info() {
	msg "Provide IP address of network interface on bastion which is connected to this same subnet,vlan where the OCP nodes are located" true
	bastion_ip=${bastion_ip:-Z}
	while $(check_input ${bastion_ip} "ip")
	do
		if [[ ! -z "$GI_BASTION_IP" ]]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_BASTION_IP] or insert bastion IP: " true "$GI_BASTION_IP"
		else
			get_input "txt" "Insert bastion IP: " false
		fi
		bastion_ip=${input_variable}
	done
	save_variable GI_BASTION_IP $bastion_ip
	msg "Provide the hostname used to resolve bastion name by local DNS which will be set up" true
        while $(check_input ${bastion_name} "txt" 1)
        do
                if [[ ! -z "$GI_BASTION_NAME" ]]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_BASTION_NAME] or insert bastion name: " true "$GI_BASTION_NAME"
                else
                        get_input "txt" "Insert bastion name: " false
                fi
                bastion_name=${input_variable}
        done
        save_variable GI_BASTION_NAME $bastion_name
	msg "Provide the IP gateway of subnet where cluster node are located" true
	while $(check_input ${subnet_gateway} "ip")
        do
                if [[ ! -z "$GI_GATEWAY" ]]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_GATEWAY] or insert IP address of default gateway: " true "$GI_GATEWAY"
                else
                        get_input "txt" "Insert IP address of default gateway: " false
                fi
                subnet_gateway=${input_variable}
        done
        save_variable GI_GATEWAY $subnet_gateway
}


function get_ocp_domain() {
	msg "Insert the OCP cluster domain name - it is local private one, so it doesn't have to be in the public domain" true
	while $(check_input ${ocp_domain} "domain")
	do
		if [[ ! -z "$GI_DOMAIN" ]]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_DOMAIN] or insert domain name: " true "$GI_DOMAIN"
		else
			get_input "txt" "Insert domain name: " false
		fi
		ocp_domain=${input_variable}
	done
	save_variable GI_DOMAIN $ocp_domain
}

function get_nodes_info() {
	local temp_ip
	local temp_mac
	local temp_name
	case $2	in
		"ocs")
			local pl_names=("addresses" "names" "IP's" "hosts") 
			local node_type="OCS nodes"
			local global_var_ip=$GI_OCS_IP
			local global_var_mac=$GI_OCS_MAC_ADDRESS
			local global_var_name=$GI_OCS_NAME
			;;
		"boot")
			local pl_names=("address" "name" "IP" "host")
                        local node_type="bootstrap node"
                        local global_var_ip=$GI_BOOTSTRAP_IP
                        local global_var_mac=$GI_BOOTSTRAP_MAC_ADDRESS
                        local global_var_name=$GI_BOOTSTRAP_NAME
                        ;;
		"mst")
			local pl_names=("addresses" "names" "IP's" "hosts") 
			local node_type="master nodes"
			local global_var_ip=$GI_MASTER_IP
			local global_var_mac=$GI_MASTER_MAC_ADDRESS
			local global_var_name=$GI_MASTER_NAME
			;;
		"wrk")
			local pl_names=("addresses" "names" "IP's" "hosts") 
			local node_type="worker nodes"
			local global_var_ip=$GI_WORKER_IP
			local global_var_mac=$GI_WORKER_MAC_ADDRESS
			local global_var_name=$GI_WORKER_NAME
			;;
		"*")
			exit 1

	esac
	msg "Insert $1 ${pl_names[2]} ${pl_names[0]} of $node_type, should be located in subnet with gateway - $subnet_gateway" true
	while $(check_input ${temp_ip} "ips" $1)
        do
                if [ ! -z "$global_var_ip" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_ip] or insert $node_type ${pl_names[2]}: " true "$global_var_ip"
                else
                        get_input "txt" "Insert $node_type IP: " false
                fi
                temp_ip=${input_variable}
        done
	msg "Insert $1 MAC ${pl_names[0]} of $node_type" true
        while $(check_input ${temp_mac} "macs" $1)
        do
                if [ ! -z "$global_var_mac" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_mac] or insert $node_type MAC ${pl_names[0]}: " true "$global_var_mac"
                else
                        get_input "txt" "Insert $node_type MAC ${pl_names[0]}: " false
                fi
                temp_mac=${input_variable}
        done
	msg "Insert $1 ${pl_names[3]} ${pl_names[1]} of $node_type" true
	while $(check_input ${temp_name} "txt_list" $1)
        do
                if [ ! -z "$global_var_name" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_name] or insert $node_type ${pl_names[1]}: " true "$global_var_name"
                else
                        get_input "txt" "Insert bootstrap ${pl_names[1]}: " false
                fi
                temp_name=${input_variable}
        done
	case $2 in
                "ocs")
			ocs_ip=$temp_ip
        		save_variable GI_OCS_IP $temp_ip
        		save_variable GI_OCS_MAC_ADDRESS $temp_mac
        		save_variable GI_OCS_NAME $temp_name
                        ;;
                "boot")
			boot_ip=$temp_ip
        		save_variable GI_BOOTSTRAP_IP $temp_ip
        		save_variable GI_BOOTSTRAP_MAC_ADDRESS $temp_mac
        		save_variable GI_BOOTSTRAP_NAME $temp_name
                        ;;
                "mst")
			master_ip=$temp_ip
        		save_variable GI_MASTER_IP $temp_ip
        		save_variable GI_MASTER_MAC_ADDRESS $temp_mac
        		save_variable GI_MASTER_NAME $temp_name
                        ;;
                "wrk")
			worker_ip=$temp_ip
			worker_name=$temp_name
        		save_variable GI_WORKER_IP $temp_ip
        		save_variable GI_WORKER_MAC_ADDRESS $temp_mac
        		save_variable GI_WORKER_NAME $temp_name
                        ;;
		"*")
			exit 1
        esac

}

function get_worker_nodes() {
	local worker_number=3
	local inserted_worker_number
	if [[ $is_master_only == 'N' ]]
	then
		if [[ $storage_type == 'O' && $ocs_tainted == 'Y' ]]
		then
			msg "Because OCS tainting has been chosen you need provide IP and MAC addresses and names of these nodes, values inserted as comma separated list without spaces" true
			get_nodes_info 3 "ocs"
		fi
		if [ $db2_tainted == 'Y' ] 
		then
			[ $gi_size == "values-small" ] && worker_number=$(($worker_number+2)) || worker_number=$(($worker_number+1))
		fi
		msg "Your cluster architecture decisions require to have minimum $worker_number additional workers" true
		while $(check_input $inserted_worker_number "int" $worker_number 50)
		do
			get_input "int" "How many additional workers would you like to add to cluster?: " false
			inserted_worker_number=${input_variable}
		done
		get_nodes_info $inserted_worker_number "wrk"
	fi
}

function set_bastion_ntp_client {
	sed -i "s/^pool .*/pool $1 iburst/g" /etc/chrony.conf
        systemctl enable chronyd
        systemctl restart chronyd
}

function get_set_services() {
	local iz_tz_ok
	local is_td_ok
	local ntpd_server
	local tzone
	local tida
	msg "Some additional questions allow to configure supporting services in your environment" true
	msg "It is recommended to use existing NTPD server in the local intranet but you can also decide to setup bastion as a new one" true
	while $(check_input $install_ntpd "yn" false)
	do
		get_input "yn" "Would you like setup NTP server on bastion?: " false
		install_ntpd=${input_variable^^}
	done
	if [[ $install_ntpd == 'N' ]]
	then
		timedatectl set-ntp true
		while $(check_input ${ntp_server} "ip")
		do
			if [ ! -z "$GI_NTP_SRV" ]
	                then
        	                get_input "txt" "Push <ENTER> to accept the previous choice [$GI_NTP_SRV] or insert remote NTP server IP address: " true "$GI_NTP_SRV"
                	else
                        	get_input "txt" "Insert remote NTP server IP address: " false
                	fi
			ntpd_server=${input_variable}
		done
		set_bastion_ntpd_client "$ntpd_server"
		save_variable GI_NTP_SRV $ntpd_server 
	fi
	msg "Ensure that TZ and corresponding time is set correctly!" true
	while $(check_input $is_tz_ok "yn" false)
	do
		get_input "yn" "Your Timezone on bastion is set to `timedatectl show|grep Timezone|awk -F '=' '{ print $2 }'`, is it correct one?: " false
		is_tz_ok=${input_variable^^}
	done
	if [[ $is_tz_ok == 'N' ]]
	then
		while $(check_input ${tzone} "tz")
		do
			get_input "txt" "Insert your Timezone in Linux format (i.e. Europe/Berlin): " false
			tzone=${input_variable}
		done
	fi
	if [[ $install_ntpd == 'Y' ]]
        then
		timedatectl set-ntp false
		save_variable GI_NTP_SRV $bastion_ip
		msg "Ensure that date and time are set correctly - it is critical!"
		while $(check_input $is_td_ok "yn" false)
        	do
                	get_input "yn" "Current local time is `date`, is it correct one?: " false
                	is_td_ok=${input_variable^^}
        	done
		if [[ $is_td_ok == 'N' ]]
	        then
        	        while $(check_input "${tida}" "td")
                	do
                        	get_input "txt" "Insert correct date and time in format \"2012-10-30 18:17:16\": " false
                        	tida="${input_variable}"
                	done
	       	fi
	fi
	msg "Provide the DNS which will able to resolve intranet and internet names" true
	msg "In case of air-gapped installation you can point bastion itself but cluster will not able to resolve intranet names, in this case you must later update manually dnsmasq.conf settings" true
	while $(check_input ${dns_fw} "ip")
        do
		if [ ! -z "$GI_DNS_FORWARDER" ]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_DNS_FORWARDER] or insert DNS server IP address: " true "$GI_DNS_FORWARDER"
		else
			get_input "txt" "Insert DNS IP address: " false
		fi
		dns_fw=${input_variable}
	done
        save_variable GI_DNS_FORWARDER $dns_fw
	IFS=',' read -r -a all_ips <<< `echo $boot_ip","$master_ip","$ocs_ip",$worker_ip"|tr -s ',,' ','|sed 's/,[[:blank:]]*$//g'`
	save_variable GI_DHCP_RANGE_START `printf '%s\n' "${all_ips[@]}"|sort -t . -k 3,3n -k 4,4n|head -n1`
	save_variable GI_DHCP_RANGE_STOP `printf '%s\n' "${all_ips[@]}"|sort -t . -k 3,3n -k 4,4n|tail -n1`
}

function get_hardware_info() {
	msg "Automatic CoreOS and storage deployment requires information about NIC and HDD devices" true
	msg "There is assumption that all cluster nodes including bootstrap machine use this isame HW specification" true
	msg "The Network Interface Card (NIC) device specification must provide the one of interfaces attached to each cluster node and connected to cluster subnet" true
	msg "In most cases the first NIC attached to machine will have on Fedora and RedHat the name \"ens192\"" true
	while $(check_input "${machine_nic}" "txt" 2)
	do
		if [ ! -z "$GI_NETWORK_INTERFACE" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_NETWORK_INTERFACE] or insert NIC specification: " true "$GI_NETWORK_INTERFACE"
                else
                        get_input "txt" "Insert NIC specification: " false
                fi
                machine_nic="${input_variable}"
	done
	save_variable GI_NETWORK_INTERFACE "$machine_nic"
	msg "There is assumption that all cluster machines use this device specification for boot disk" true
	msg "In most cases the first boot disk will have specification \"sda\" or \"nvmne0\"" true
	msg "The inserted value refers to root path located in /dev" true
	msg "It means that value sda refers to /dev/sda" true
	while $(check_input "${machine_disk}" "txt" 2)
        do
                if [ ! -z "$GI_BOOT_DEVICE" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_BOOT_DEVICE] or insert boot disk specification: " true "$GI_BOOT_DEVICE"
                else
                        get_input "txt" "Insert boot disk specification: " false
                fi
                machine_disk="${input_variable}"
        done
        save_variable GI_BOOT_DEVICE "$machine_disk"
}

function get_service_assignment() {
	local selected_arr
	local node_arr
	if [[ $gi_install == 'Y' ]] 
	then
		[[ $gi_size == 'values-small' ]] && db2_nodes_size=2 || db2_nodes_size=1
		msg "You decided that DB2 will be installed on dedicated nodes" true
		msg "These nodes should not be used as storage cluster nodes" true
		msg "Available worker nodes: $worker_name" true
		while $(check_input $db2_nodes "nodes" $worker_name $db2_nodes_size "def")
                do
			if [ ! -z "$GI_DB2_NODES" ]
			then
				get_input "txt" "Push <ENTER> to accept the previous choice [$GI_DB2_NODES] or specify $db2_nodes_size node/nodes (comma separated, without spaces)?: " true "$GI_DB2_NODES"
			else
				get_input "txt" "Specify $db2_nodes_size node/nodes (comma separated, without spaces)?: " false
			fi
                        db2_nodes=${input_variable}
                done
		save_variable GI_DB2_NODES "$db2_nodes"
		IFS=',' read -r -a selected_arr <<< "$db2_nodes"
		IFS=',' read -r -a node_arr <<< "$worker_name"
		for element in ${selected_arr[@]};do node_arr=("${node_arr[@]/$element}");done
		worker_wo_db2_name=`echo ${node_arr[*]}|tr ' ' ','`
		workers_for_gi_selection=$worker_wo_db2_name
		if [[ "$db2_tainted" == 'N' ]]
		then
			worker_wo_db2_name=$worker_name
		fi
	fi
	if [[ $storage_type == "R" && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
	then
		msg "You specified Rook-Ceph as cluster storage" true
		msg "You can force to deploy it on strictly defined node list" true
		msg "Only disks from specified nodes will be configured as cluster storage" true
		while $(check_input $rook_on_list "yn" false)
        	do
                	get_input "yn" "Would you like to install Rook-Ceph on strictly specified nodes?: " true
                	rook_on_list=${input_variable^^}
        	done
		if [ "$rook_on_list" == 'Y' ]
		then
			msg "Available worker nodes: $worker_wo_db2_name" true
                	while $(check_input $rook_nodes "nodes" $worker_wo_db2_name 3 "def")
                	do
                        	if [ ! -z "$GI_ROOK_NODES" ]
                        	then
                                	get_input "txt" "Push <ENTER> to accept the previous choice [$GI_ROOK_NODES] or specify 3 nodes (comma separated, without spaces)?: " true "$GI_ROOK_NODES"
                        	else
                                	get_input "txt" "Specify 3 nodes (comma separated, without spaces)?: " false
                        	fi
                        	rook_nodes=${input_variable}
                	done
		fi
	fi
        save_variable GI_ROOK_NODES "$rook_nodes"
	if [[ $ics_install == "Y" && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
        then
                msg "You can force to deploy ICS on strictly defined node list" true
                while $(check_input $ics_on_list "yn" false)
                do
                        get_input "yn" "Would you like to install ICS on strictly specified nodes?: " true
                        ics_on_list=${input_variable^^}
                done
		if [ "$ics_on_list" == 'Y' ]
		then
                	msg "Available worker nodes: $worker_wo_db2_name" true
                	while $(check_input $ics_nodes "nodes" $worker_wo_db2_name 3 "def")
                	do
                        	if [ ! -z "$GI_ICS_NODES" ]
                        	then
                                	get_input "txt" "Push <ENTER> to accept the previous choice [$GI_ICS_NODES] or specify 3 nodes (comma separated, without spaces)?: " true "$GI_ICS_NODES"
                        	else
                                	get_input "txt" "Specify 3 nodes (comma separated, without spaces)?: " false
                        	fi
                        	ics_nodes=${input_variable}
                	done
		fi
        fi
	save_variable GI_ICS_NODES "$ics_nodes"
	if [ "$gi_install" == 'Y' ]
	then
		IFS=',' read -r -a worker_arr <<< "$worker_name"
		if [[ ( $db2_tainted == 'Y' && ${#node_arr[@]} -gt 3 ) ]] || [[ ( $db2_tainted == 'N' && "$gi_size" == "values-small" && ${#worker_arr[@]} -gt 5 ) ]] || [[ ( $db2_tainted == 'N' && "$gi_size" == "values-dev" && ${#worker_arr[@]} -gt 4 ) ]]
		then
			msg "You can force to deploy GI on strictly defined node list" true
                	while $(check_input $gi_on_list "yn" false)
                	do
                        	get_input "yn" "Would you like to install GI on strictly specified nodes?: " true
                        	gi_on_list=${input_variable^^}
                	done
		fi
		if [[ $db2_tainted == 'Y' && ${#node_arr[@]} -gt 3 ]]
		then
			no_nodes_2_select=3
		else
			[ "$gi_size" == "values-small" ] && no_nodes_2_select=1 || no_nodes_2_select=2
		fi
		if [ "$gi_on_list" == 'Y' ]
                then
			if [ ! -z "$GI_GI_NODES" ]
			then
				local previous_node_ar
				local current_selection
				IFS=',' read -r -a previous_node_arr <<< "$GI_GI_NODES"
				IFS=',' read -r -a db2_node_arr <<< "$db2_nodes"
                                for element in ${db2_node_arr[@]};do previous_node_arr=("${previous_node_arr[@]/$element}");done
				current_selection=`echo ${previous_node_arr[*]}|tr ' ' ','`
			fi
                        msg "DB2 node/nodes: $db2_nodes are already on the list included, additionally you must select minimum $no_nodes_2_select node/nodes from the list below:" true
			msg "Available worker nodes: $workers_for_gi_selection" true
                        while $(check_input $gi_nodes "nodes" $workers_for_gi_selection $no_nodes_2_select "max")
                        do
                                if [ ! -z "$GI_GI_NODES" ]
                                then
                                        get_input "txt" "Push <ENTER> to accept the previous choice [$current_selection] or specify minimum $no_nodes_2_select node/nodes (comma separated, without spaces)?: " true "$current_selection"
                                else
                                        get_input "txt" "Specify minimum $no_nodes_2_select node/nodes (comma separated, without spaces)?: " false
                                fi
                                gi_nodes=${input_variable}
                        done
                fi
	fi
	save_variable GI_GI_NODES "${db2_nodes},$gi_nodes"
}

function get_cluster_storage_info() {
	# add support to point more than one device per node
	msg "There is assumption that all storage cluster node use this same device specification for storage disk" true
        msg "In most cases the second boot disk will have specification \"sdb\" or \"nvmne1\"" true
        msg "The inserted value refers to root path located in /dev" true
        msg "It means that value sdb refers to /dev/sdb" true
        while $(check_input "${storage_device}" "txt" 2)
        do
                if [ ! -z "$GI_STORAGE_DEVICE" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_STORAGE_DEVICE] or insert cluster storage disk device specification: " true "$GI_STORAGE_DEVICE"
                else
                        get_input "txt" "Insert cluster storage disk device specification: " false
                fi
                storage_device="${input_variable}"
        done
        save_variable GI_STORAGE_DEVICE "$storage_device"
	msg "Cluster storage devices ($storage_device)  must be this same size on all storage nodes!" true
	msg "The minimum size of each disk is 100 GB" true
        while $(check_input "${storage_device_size}" "int" 100 10000000)
        do
                if [ ! -z "$GI_STORAGE_DEVICE_SIZE" ]
                then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_STORAGE_DEVICE_SIZE] or insert cluster storage disk device size (in GB): " true "$GI_STORAGE_DEVICE_SIZE"
			storage_device_size="$GI_STORAGE_DEVICE_SIZE"
                else
			get_input "txt" "Insert cluster storage disk device size (in GB): " false
                fi
                storage_device_size="${input_variable}"
        done
        save_variable GI_STORAGE_DEVICE_SIZE "$storage_device_size"
}

function get_inter_cluster_info() {
	msg "Pods in cluster communicate with one another using private network, use non-default values only if your physical network use IP address space 10.128.0.0/16" true
	while $(check_input "${ocp_cidr}" "cidr")
        do
                if [ ! -z "$GI_OCP_CIDR" ]
                then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_OCP_CIDR] or insert cluster interconnect CIDR (IP/MASK): " true "$GI_OCP_CIDR"
                else
                        get_input "txt" "Insert cluster interconnect CIDR (default - 10.128.0.0/16): " true "10.128.0.0/16"
                fi
                ocp_cidr="${input_variable}"
        done
        save_variable GI_OCP_CIDR "$ocp_cidr"
	cidr_subnet=$(echo "$ocp_cidr"|awk -F'/' '{print $2}')
	msg "Each pod will reserve IP address range from subnet $ocp_cidr, provide this range using subnet mask (must be higher than $cidr_subnet)" true
        while $(check_input "${ocp_cidr_mask}" "int" $cidr_subnet 27)
        do
                if [ ! -z "$GI_OCP_CIDR_MASK" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_OCP_CIDR_MASK] or insert pod IP address range (MASK): " true "$GI_OCP_CIDR_MASK"
                else
                        get_input "txt" "Insert pod IP address range (default - 23): " true 23
                fi
                ocp_cidr_mask="${input_variable}"
        done
        save_variable GI_OCP_CIDR_MASK "$ocp_cidr_mask"
}

function get_credentials() {
	local is_ok=true #there is no possibility to send variable with unescaped json
	if [ $use_air_gap == 'N' ]
	then
		msg "Non air-gapped OCP installations requires access to remote image registries located in the Internet" true
		msg "Access to OCP images is restricted and requires authorization using RedHat account pull secret" true
		msg "You can get access to your pull secret at this URL - https://cloud.redhat.com/openshift/install/local" true
		while $is_ok
		do
                	if [ ! -z "$GI_RHN_SECRET" ]
                	then
				msg "Push <ENTER> to accept the previous choice" true
				msg "[$GI_RHN_SECRET]" true
                        	get_input "txt" "or insert RedHat pull secret: " true "$GI_RHN_SECRET"
                	else
                        	get_input "txt" "Insert RedHat pull secret: " false
                	fi
                	if [ "${input_variable}" ]
			then
				echo ${input_variable}|{ jq .auths 2>/dev/null 1>/dev/null ;}
				[[ $? -eq 0 ]] && is_ok=false
				rhn_secret="${input_variable}"
			fi
        	done
        	save_variable GI_RHN_SECRET "'${input_variable}'"
		if [[ $gi_install == 'Y' ]]
		then
			msg "Guardium Insights installation requires access to restricted IBM image registries" true
			msg "You need provide the IBM Cloud container key located at URL - https://myibm.ibm.com/products-services/containerlibrary" true
			msg "Your account must be entitled to install GI" true
			while $(check_input "${ibm_secret}" "jwt")
        		do
                		if [ ! -z "$GI_IBM_SECRET" ]
                		then
					msg "Push <ENTER> to accept the previous choice" true
					msg "[$GI_IBM_SECRET]" true
                        		get_input "txt" "or insert IBM Cloud container key: " true "$GI_IBM_SECRET"
                		else
                        		get_input "txt" "Insert IBM Cloud container key: " false
                		fi
                		ibm_secret="${input_variable}"
        		done
        		save_variable GI_IBM_SECRET "'$ibm_secret'"
		fi

	fi
	msg "Define user name and password of an additional OpenShift administrator" true
	while $(check_input "${ocp_admin}" "txt" 2)
        do
                if [ ! -z "$GI_OCADMIN" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_OCADMIN] or insert OCP admin username: " true "$GI_OCADMIN"
                else
                        get_input "txt" "Insert OCP admin username (default - ocadmin): " true "ocadmin"
                fi
                ocp_admin="${input_variable}"
        done
        save_variable GI_OCADMIN "$ocp_admin"
	while $(check_input "${ocp_password}" "txt" 2)
        do
                if [ ! -z "$GI_OCADMIN_PWD" ]
                then
                        get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_OCADMIN_PWD] or insert OCP $ocp_admin user password" true "$GI_OCADMIN_PWD"
                else
                        get_input "pwd" "Insert OCP $ocp_admin user password" false
                fi
                ocp_password="${input_variable}"
        done
        save_variable GI_OCADMIN_PWD "'$ocp_password'"
	if [[ "$gi_install" == 'Y' || "$ics_install" == 'Y' ]]
	then
		msg "Define ICS admin user password" true
	        msg "This same account is used by GI for default account with access management role" true
		while $(check_input "${ics_password}" "txt" 2)
        	do
                	if [ ! -z "$GI_ICSADMIN_PWD" ]
                	then
                        	get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_ICSADMIN_PWD] or insert ICS admin user password" true "$GI_ICSADMIN_PWD"
                	else
                        	get_input "pwd" "Insert OCP admin user password" false
                	fi
                	ics_password="${input_variable}"
        	done
        	save_variable GI_ICSADMIN_PWD "'$ics_password'"
	fi
	if [[ "$install_ldap" == 'Y' ]]
        then
                msg "Define LDAP users initial password" true
                while $(check_input "${ldap_password}" "txt" 2)
                do
                        if [ ! -z "$GI_LDAP_USERS_PWD" ]
                        then
                                get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_LDAP_USERS_PWD] or insert default LDAP users password" true "$GI_LDAP_USERS_PWD"
                        else
                                get_input "pwd" "Insert default LDAP users password" false
                        fi
                        ldap_password="${input_variable}"
                done
                save_variable GI_LDAP_USERS_PWD "'$ldap_password'"
	fi
}

function validate_certs() {
	local pre_value_ca
	local pre_value_app
	local pre_value_key
	local ca_cert
	local app_cert
	local app_key
	local label
	local cert_info
	case $1 in
                "ocp")
			label="OCP"
			cert_info="$label certificate must have ASN (Alternate Subject Name) set to \"*.apps.${ocp_domain}\""
                        pre_value_ca="$GI_OCP_IN_CA"
                        pre_value_app="$GI_OCP_IN_CERT"
                        pre_value_key="$GI_OCP_IN_KEY"
                        ;;
                "ics")
			label="ICS"
			cert_info="$label certificate must have ASN (Alternate Subject Name) set to \"cp-console.apps.${ocp_domain}\""
                        pre_value_ca="$GI_ICS_IN_CA"
                        pre_value_app="$GI_ICS_IN_CERT"
                        pre_value_key="$GI_ICS_IN_KEY"
			;;
                "gi")
			label="GI"
			cert_info="$label certificate must have ASN (Alternate Subject Name) set to \"insights.apps.${ocp_domain}\""
                        pre_value_ca="$GI_IN_CA"
                        pre_value_app="$GI_IN_CERT"
                        pre_value_key="$GI_IN_KEY"
			;;
                "*")
                        exit 1
                        ;;
        esac
	while $(check_input "${ca_cert}" "cert" "ca")
	do
		if [ ! -z "$pre_value_ca" ]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$pre_value_ca] or insert the full path to root CA of $label certificate" true "$pre_value_ca"
		else
			get_input "txt" "Insert the full path to root CA of $label certificate: " false
		fi
		ca_cert="${input_variable}"
        done
	msg "$cert_info" true
	while $(check_input "${app_cert}" "cert" "app" "$ca_cert")
	do
		if [ ! -z "$pre_value_app" ]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$pre_value_app] or insert the full path to $label certificate" true "$pre_value_app"
		else
			get_input "txt" "Insert the full path to $label certificate: " false
		fi
		app_cert="${input_variable}"
        done
	while $(check_input "${app_key}" "cert" "key" "$app_cert")
	do
		if [ ! -z "$pre_value_key" ]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$pre_value_key] or insert the full path to $label private key" true "$pre_value_key"
		else
			get_input "txt" "Insert the full path to $label private key: " false
		fi
		app_key="${input_variable}"
        done

	case $1 in
                "ocp")
			save_variable GI_OCP_IN_CA "$ca_cert"
			save_variable GI_OCP_IN_CERT "$app_cert"
			save_variable GI_OCP_IN_KEY "$app_key"
                        ;;
                "ics")
			save_variable GI_ICS_IN_CA "$ca_cert"
			save_variable GI_ICS_IN_CERT "$app_cert"
			save_variable GI_ICS_IN_KEY "$app_key"
                        ;;
                "gi")
			save_variable GI_IN_CA "$ca_cert"
			save_variable GI_IN_CERT "$app_cert"
			save_variable GI_IN_KEY "$app_key"
			;;
                "*")
                        exit 1
                        ;;
        esac
}
function get_certificates() {
	msg "You can replace self-signed certicates for UI's by providing your own created by trusted CA" true
	msg "Certificates must be uploaded to bastion to provide full path to them" true
	msg "CA cert, service cert and private key files must be stored separately in PEM format" true
	while $(check_input "$ocp_ext_ingress" "yn" false)
        do
	        get_input "yn" "Would you like to install own certificates for OCP?: " true
                ocp_ext_ingress=${input_variable^^}
	done
	save_variable GI_OCP_IN $ocp_ext_ingress
	[ $ocp_ext_ingress == 'Y' ] && validate_certs "ocp"
	if [[ "$gi_install" == 'Y' || "$ics_install" == 'Y' ]]
        then
		while $(check_input "$ics_ext_ingress" "yn" false)
        	do
                	get_input "yn" "Would you like to install own certificates for ICP?: " true
                	ics_ext_ingress=${input_variable^^}
        	done
        	save_variable GI_ICS_IN $ics_ext_ingress
        	[ $ics_ext_ingress == 'Y' ] && validate_certs "ics"
	fi
	if [[ "$gi_install" == 'Y' ]]
        then
                while $(check_input "$gi_ext_ingress" "yn" false)
                do
                        get_input "yn" "Would you like to install own certificates for GI?: " true
                        gi_ext_ingress=${input_variable^^}
                done
                save_variable GI_IN $gi_ext_ingress
                [ $gi_ext_ingress == 'Y' ] && validate_certs "gi"
        fi
}

function get_gi_options() {
	msg "Guardium Insights deployment requires some decisions such as storage size, functions enabled" true
	while $(check_input "${gi_namespace}" "txt" 3 10)
        do
                if [ ! -z "$GI_NAMESPACE_GI" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_NAMESPACE_GI] or insert GI namespace name (maximum 10 characters)" true "$GI_NAMESPACE_GI"
                else
                        get_input "txt" "Insert GI namespace name (maximum 10 characters, default gi): " true "gi"
                fi
                gi_namespace="${input_variable}"
        done
	save_variable GI_NAMESPACE_GI $gi_namespace
	while $(check_input "$db2_enc" "yn" false)
        do
                get_input "yn" "Should be DB2u tablespace encrypted?: " true
                db2_enc=${input_variable^^}
        done
	save_variable GI_DB2_ENCRYPTED $db2_enc
	if [[ $gi_version_selected -ge 3 ]]
        then
		while $(check_input "$stap_supp" "yn" false)
        	do
                	get_input "yn" "Should be enabled the direct streaming from STAP's?: " false
                	stap_supp=${input_variable^^}
        	done
        	save_variable GI_STAP_STREAMING $stap_supp

	fi
	get_gi_pvc_size
}

function pvc_sizes() {
	local global_var
	local global_var_val
	local curr_value
	local size_min=20
	local size_max=1000000
	local m_desc
	local m_ask
	local v_aux1
	case $1 in
		"db2-data")
			size_min=150
			[[ "gi_size" != "values-dev" ]] && v_aux1=2 || v_aux=1
			m_desc="DB2 DATA pvc - stores activity events, installation proces will create $v_aux1 PVC/PVC's, each instance contains different data"
			m_ask="DB2 DATA pvc, minium size $size_min GB"
			global_var="GI_DATA_STORAGE_SIZE"
			global_var_val="$GI_DATA_STORAGE_SIZE"
			;;
		"db2-meta")
			size_min=100
			m_desc="DB2 METADATA pvc - stores DB2 shared, temporary, tool files, installation proces will create 1 PVC"
			m_ask="DB2 METADATA pvc, minimum size $size_min GB"
			global_var="GI_METADATA_STORAGE_SIZE"
			global_var_val="$GI_METADATA_STORAGE_SIZE"
			;;
		"db2-logs")
			size_min=100
			[[ "gi_size" != "values-dev" ]] && v_aux1=2 || v_aux=1
			m_desc="DB2 ACTIVELOG pvc - stores DB2 transactional logs, installation process will create $v_aux1 PVC/PVC's, each instance contains different data"
			m_ask="DB2 ACTIVELOG pvc, minium size $size_min GB"
			global_var="GI_ACTIVELOGS_STORAGE_SIZE"
			global_var_val="$GI_ACTIVELOGS_STORAGE_SIZE"
			;;
		"mongo-data")
			size_min=50
			[[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
			m_desc="MONGODB DATA pvc - stores MongoDB data related to GI metadata and reports, installation process will create $v_aux1 PVC/PVC's, each instance contains this same data"
			m_ask="MONGODB DATA pvc, minium size $size_min GB"
			global_var="GI_MONGO_DATA_STORAGE_SIZE"
			global_var_val="$GI_MONGO_DATA_STORAGE_SIZE"
			;;
		"mongo-logs")
			size_min=10
			[[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
			m_desc="MONGODB LOG pvc - stores MongoDB logs, installation process will create $v_aux1 PVC/PVC's, each instance contains different data"
			m_ask="MONGODB LOG pvc, minium size $size_min GB"
			global_var="GI_MONGO_METADATA_STORAGE_SIZE"
			global_var_val="$GI_MONGO_METADATA_STORAGE_SIZE"
			;;
		"kafka")
			size_min=50
			[[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
			m_desc="KAFKA pvc - stores ML and Streaming data for last 7 days, installation process will create $v_aux1 PVC/PVC's, each instance contains this same data"
			m_ask="KAFKA pvc, minium size $size_min GB"
			global_var="GI_KAFKA_STORAGE_SIZE"
			global_var_val="$GI_KAFKA_STORAGE_SIZE"
			;;
		"zookeeper")
			size_min=5
			[[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
			m_desc="ZOOKEEPER pvc - stores Kafka configuration and health data, installation process will create $v_aux1 PVC/PVC's, each instance contains this same data"
			m_ask="ZOOKEEPER pvc, minium size $size_min GB"
			global_var="GI_ZOOKEEPER_STORAGE_SIZE"
			global_var_val="$GI_ZOOKEEPER_STORAGE_SIZE"
			;;
		"*")
			exit 1
			;;
	esac
	while $(check_input "${curr_value}" "int" $size_min $size_max)
	do
		msg "$m_desc" true
		if [ ! -z "$global_var_val" ]
		then
			get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_val] or insert size of $m_ask: " true "$global_var_val"
		else
			get_input "txt" "Insert size of $m_ask: " false
		fi
		curr_value="${input_variable}"
	done
	save_variable $global_var $curr_value
}

function get_gi_pvc_size() {
	local custom_pvc
	msg "The cluster storage contains 3 disks - ${storage_device_size} GB each" true
	[[ "storage_type" == 'O' ]] && msg "OCS creates 3 copies of data chunks so you have ${storage_device_size} of GB effective space for PVC's" true || msg "Rook-Ceph creates 2 copies of data chunks so you have $((2*${storage_device_size})) GB effective space for PVC's" true
	while $(check_input "$custom_pvc" "yn")
        do
		get_input "yn" "Would you like customize Guardium Insights PVC sizes (default) or use default settings?: " false
                custom_pvc=${input_variable^^}
        done
	if [ $custom_pvc == 'Y' ]
	then
		pvc_arr=("db2-data" "db2-meta" "db2-logs" "mongo-data" "mongo-logs" "kafka" "zookeeper")
		for pvc in ${pvc_arr[@]};do pvc_sizes $pvc;done
	else
		local pvc_variables=("GI_DATA_STORAGE_SIZE" "GI_METADATA_STORAGE_SIZE" "GI_ACTIVELOGS_STORAGE_SIZE" "GI_MONGO_DATA_STORAGE_SIZE" "GI_MONGO_METADATA_STORAGE_SIZE" "GI_KAFKA_STORAGE_SIZE" "GI_ZOOKEEPER_STORAGE_SIZE")
		for pvc in ${pvc_variables[@]};do save_variable $pvc 0;done
	fi
}

function get_ics_options() {
	local operand
	local curr_op
	msg "ICS provides set of operands which can be installed during installation, some of them are required and others can be used by IBM Cloud Packs installed on the top of it" true
	msg "Define which operands should be additionally installed" true
	local operand_list=("Zen,N" "Monitoring,Y" "Event_Streams,Y" "Logging,Y" "MongoDB,Y" "User_Data_Services",N" ""Apache_Spark,N" "IBM_API_Catalog,N" "Business_Teams,N")
	declare -a ics_ops
	for operand in ${operand_list[@]}
	do
		unset op_option
		IFS="," read -r -a curr_op <<< $operand
		while $(check_input "$op_option" "yn")
		do
			get_input "yn"  "Would you like to install ${curr_op[0]//_/ } operand: " $([[ "${curr_op[1]}" != 'Y' ]] && echo true || echo false)
                	op_option=${input_variable^^}
		done
		ics_ops+=($op_option)
	done
	save_variable GI_ICS_OPERANDS $(echo ${ics_ops[@]}|awk 'BEGIN { FS= " ";OFS="," } { $1=$1 } 1')
}

function get_ldap_options() {
	msg "OpenLDAP deployment parameters"
	while $(check_input "$ldap_depl" "cs")
        do
		get_input "cs" "Decide where LDAP instance should be deployed as Container on OpenShift (default) or as Standalone installation on bastion:? (\e[4mC\e[0m)ontainer/Ba(s)tion " true

                ldap_depl=${input_variable^^}
        done
	save_variable GI_LDAP_DEPLOYMENT $ldap_depl
	msg "Define LDAP domain distinguished name, only DC components are allowed" true
        while $(check_input "${ldap_domain}" "ldap_domain")
        do
        	if [ ! -z "$GI_LDAP_DOMAIN" ]
        	then
	        	get_input "txt" "Push <ENTER> to accept the previous choice [$GI_LDAP_DOMAIN] or insert LDAP organization domain DN: " true "$GI_LDAP_DOMAIN"
        	else
                	get_input "txt" "Insert LDAP organization domain DN (for example: DC=io,DC=priv): " false
        	fi
                        ldap_domain="${input_variable}"
        done
        save_variable GI_LDAP_DOMAIN "'$ldap_domain'"
	msg "Provide list of users which will be created in OpenLDAP instance" true
        while $(check_input "${ldap_users}" "users_list")
        do
                if [ ! -z "$GI_LDAP_USERS" ]
                then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_LDAP_USERS] or insert comma separated list of LDAP users (without spaces): " true "$GI_LDAP_USERS"
                else
                        get_input "txt" "Insert comma separated list of LDAP users (without spaces): " false
                fi
                        ldap_users="${input_variable}"
        done
        save_variable GI_LDAP_USERS "'$ldap_users'"
}

function configure_os_for_proxy() {
	msg "To support installation over Proxy some additional information must be gathered and bastion network services reconfiguration" true
	msg "HTTP Proxy IP address" true
	while $(check_input "${proxy_ip}" "ip")
        do
                if [[ ! -z "$GI_PROXY_URL" && "$GI_PROXY_URL" != "NO_PROXY" ]]
                then
			local saved_proxy_ip=$(echo "$GI_PROXY_URL"|awk -F':' '{print $1}')
                        get_input "txt" "Push <ENTER> to accept the previous choice [$saved_proxy_ip] or insert IP address of Proxy server: " true "$saved_proxy_ip"
                else
                        get_input "txt" "Insert IP address of Proxy server: " false
                fi
                        proxy_ip="${input_variable}"
        done
	msg "HTTP Proxy port" true
        while $(check_input "${proxy_port}" "int" 1024 65535)
        do
                if [[ ! -z "$GI_PROXY_URL" && "$GI_PROXY_URL" != "NO_PROXY" ]]
                then
                        local saved_proxy_port=$(echo "$GI_PROXY_URL"|awk -F':' '{print $2}')
                        get_input "txt" "Push <ENTER> to accept the previous choice [$saved_proxy_port] or insert Proxy server port: " true "$saved_proxy_port"
                else
                        get_input "txt" "Insert Proxy server port: " false
                fi
                        proxy_port="${input_variable}"
        done
	msg "You can exclude from proxy redirection the access to the intranet subnets" true
	no_proxy="init_value"
	while $(check_input "${no_proxy}" "cidr_list" true)
        do
                        get_input "txt" "Insert comma separated list of CIDRs (like 192.168.0.0/24) which should not be proxied (do not need provide here cluster addresses): " false
                        no_proxy="${input_variable}"
        done
        no_proxy="127.0.0.1,*.apps.$ocp_domain,*.$ocp_domain,$no_proxy"
        msg "Your proxy settings are:" true
        msg "Proxy URL: http://$proxy_ip:$proxy_port" true
	msg "System will not use proxy for: $no_proxy" true
        msg "Setting your HTTP proxy environment on bastion" true
        msg "- Modyfying /etc/profile" true
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
        msg "- Add proxy settings to DNF config file" true
        cp -f /etc/dnf/dnf.conf /etc/dnf/dnf.conf.gi_no_proxy
        if [[ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^proxy=.*/proxy=http:\/\/$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
        else
                echo "proxy=http://$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf
        fi
	save_variable GI_NOPROXY_NET "$no_proxy"
	save_variable GI_PROXY_URL "$proxy_ip:$proxy_port"
}

function unset_proxy_settings() {
	if [[ -f /etc/profile.gi_no_proxy ]]
        then
                mv -f /etc/profile.gi_no_proxy /etc/profile
        fi
        if [[ -f /etc/dnf/dnf.conf.gi_no_proxy ]]
        then
                mv -f /etc/dnf/dnf.conf.gi_no_proxy /etc/dnf/dnf.conf
        fi
	save_variable GI_PROXY_URL "NO_PROXY"

}

function create_cluster_ssh_key() {
	msg "*** Add a new RSA SSH key ***" true
	cluster_id=$(mktemp -u -p ~/.ssh/ cluster_id_rsa.XXXXXXXXXXXX)
	msg "*** Cluster key: ~/.ssh/${cluster_id}, public key: ~/.ssh/${cluster_id}.pub ***" true
	ssh-keygen -N '' -f ${cluster_id} -q <<< y > /dev/null
	echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > ~/.ssh/config
	cat ${cluster_id}.pub >> /root/.ssh/authorized_keys
	save_variable GI_SSH_KEY "${cluster_id}"
	msg "Save SSH keys names: ${cluster_id} and ${cluster_id}.pub, each init.sh execution create new with random name" true
}

function setup_online_installation() {
	msg "*** Updating Fedora to have up to date software packages ***" true
        dnf -qy update
        msg "*** Installing Ansible and other Fedora packages ***" true
	local soft=("tar" "ansible" "haproxy" "openldap" "perl" "podman-docker" "ipxe-bootimgs" "chrony" "dnsmasq" "unzip" "wget" "jq" "httpd-tools" "policycoreutils-python-utils" "python3-ldap" "openldap-servers" "openldap-clients" "pip" "skopeo")
	for package in "${soft[@]}"
	do
		msg " - installing $package ..." true
		dnf -qy install $package &>/dev/null
		[[ $? -ne 0 ]] && exit 1
	done
        msg "*** Installing Python packages ***" true
	local python_soft=("passlib" "dnspython" "beautifulsoup4")
	for package in "${python_soft[@]}"
	do
		msg " - installing $package ..." true
		[[ $use_proxy == 'D' ]] && pip3 install "$package" || pip3 install "$package" --proxy http://$proxy_ip:$proxy_port
		[[ $? -ne 0 ]] && exit 1
	done
        msg "*** Configuring Ansible ***" true
        mkdir -p /etc/ansible
        [[ $use_proxy == 'P' ]] && echo -e "[bastion]\n127.0.0.1 \"http_proxy=http://$proxy_ip:$proxy_port\" https_proxy=\"http://$proxy_ip:$proxy_port\" ansible_connection=local" > /etc/ansible/hosts || echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
        echo "pullSecret: '$rhn_secret'" > scripts/pull_secret.tmp
}

function setup_offline_installation() {
	msg "Offline installation requires setup the local image repository on bastion" true
	while $(check_input "${repo_admin}" "txt" 1)
        do
                if [[ ! -z "$GI_REPO_USER" ]]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_REPO_USER] or insert local registry username: " true "$GI_REPO_USER"
                else
			get_input "txt" "Insert local registry username (default - repoadmin): " true "repoadmin"
                fi
                        repo_admin="${input_variable}"
        done
	save_variable GI_REPO_USER $repo_admin
	while $(check_input "${repo_admin_pwd}" "txt" 2)
        do
                if [ ! -z "$GI_REPO_USER_PWD" ]
                then
                        get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_REPO_USER_PWD] or insert new local image registry $repo_admin user password" true "$GI_REPO_USER_PWD"
                else
                        get_input "pwd" "Insert OCP $ocp_admin user password" false
                fi
                repo_admin_pwd="${input_variable}"
        done
        save_variable GI_REPO_USER_PWD "'$repo_admin_pwd'"
	msg "Offline installation requires installation archives preparation using preinstall scripts" true
	msg "Archives must be copied to bastion before installation"
	while $(check_input "${gi_archives}" "txt" 1)
        do
                if [[ ! -z "$GI_ARCHIVES_DIR" ]]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_ARCHIVES_DIR] or insert the full path to installation archives: " true "$GI_ARCHIVES_DIR"
                else
			get_input "txt" "Insert full path to installation archives (default location - $GI_HOME/download): " true "$GI_HOME/download"
                fi
                        gi_archives="${input_variable}"
        done
	save_variable GI_ARCHIVES_DIR "$gi_archives"	
	exit 1
        msg "*** Check OS files archive existence ***" true
        if [[ `ls $gi_archives/os*.tar 2>/dev/null|wc -l` -ne 1 ]]
        then
                echo "You did not upload os-<version>.tar to $gi_archives directory on bastion"
                exit 1
        fi
        msg "*** Checking source and target kernel ***" true
        tar -C $GI_TEMP -xf ${gi_archives}/os*.tar kernel.txt ansible/* galaxy/* os-packages/* os-updates/*
        if [[ `uname -r` != `cat $GI_TEMP/kernel.txt` ]]
        then
                msg "Kernel of air-gap bastion differs from air-gap file generator!" true
		msg "In most cases the independent kernel update will lead to problems with system libraries" true 
                read -p "Have you updated system before, would you like to continue (Y/N)?: " is_updated
                if [ $is_updated != 'N' ]
                then
                        msg "Upload air-gap files corresponding to bastion kernel or generate files for bastion environment."
                        exit 1
                fi
        fi
	rm -f $GI_TEMP/kernel.txt
        msg  "*** Installing OS updates ***" true
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os-updates/*rpm --allowerasing
        rm -rf ${GI_TEMP}/os-updates
        msg "*** Installing OS packages ***" true
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os-packages/*rpm --allowerasing
        rm -rf ${GI_TEMP}/os-packages
        msg "*** Installing Ansible and python modules ***" true
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
}

function prepare_bastion_to_execute_playbooks() {
	msg "Installation process is managed by Ansible playbooks, now additional software will be installed ..." true
	[[ "$use_air_gap" == 'N' ]] && setup_online_installation || setup_offline_installation
}

#MAIN PART

msg "#gi-runner configuration file" true > $file
msg "This script must be executed from gi-runner home directory" true
msg "*** Checking OS release ***" true
#install tools for init.sh
dnf -y install jq
save_variable KUBECONFIG "$GI_HOME/ocp/auth/kubeconfig"
check_bastion_os
get_network_installation_type
get_software_selection
get_software_architecture
get_ocp_domain
get_bastion_info
msg "Provide information about bootstrap node IP and MAC address and its name" true
get_nodes_info 1 "boot"
msg "Control Plane requires 3 master nodes, provide information about their IP and MAC addresses and names, values inserted as comma separated list without spaces" true
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
[[ "$gi_install" == 'Y' ]] && save_variable GI_ICS_OPERANDS "N,N,Y,Y,Y,N,N,N,N"
[[ "$ics_install" == 'Y' && "$gi_install" == 'N' ]] && get_ics_options
[[ "$install_ldap" == 'Y' ]] && get_ldap_options
[[ $use_air_gap == 'Y' && $use_proxy='P' ]] && configure_os_for_proxy || unset_proxy_settings
create_cluster_ssh_key
prepare_bastion_to_execute_playbooks
msg "*** Execute commands below ***" true
[[ $use_proxy == 'P' ]] &&  echo "- import PROXY settings: \". /etc/profile\""
msg " - import variables: \". $file\"" true
msg " - start first playbook: \"ansible-playbook playbooks/01-finalize-bastion-setup.yaml\"" true

