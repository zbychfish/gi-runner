function ansible_constants() {
	local afile
	local arr_values
	afile=$GI_HOME/plays/constants.yaml
	echo "# gi-runner playbooks constants" > $afile
	echo "skip_phase: 0" >> $afile
	echo 'clean_downloads: "N"' >> $afile
	echo "temp_dir: $GI_TEMP" >> $afile
	echo "matchbox_version: $matchbox_version" >> $afile
	echo "ibm_pak_version: $ibm_pak_version" >> $afile
	echo "rook_operator_version: $rook_operator_version" >> $afile
	echo "rook_ceph_version: $rook_ceph_version" >> $afile
	printf -v arr_values '"%s",' "${ics_versions[@]}"
	echo "cpfs_versions: [ ${arr_values%,} ]" >> $afile
	printf -v arr_values '"%s",' "${ics_cases[@]}"
	echo "cpfs_cases: [ ${arr_values%,} ]" >> $afile
	echo "cpfs_operator_namespace: $cpfs_operator_namespace" >> $afile
	echo "cpfs_case_name: $cpfs_case_name" >> $afile
	echo "cpfs_case_inventory_setup: $cpfs_case_inventory_setup" >> $afile
	echo "cpfs_update_channel: $cpfs_update_channel" >> $afile
	echo "nfs_provisioner_version: $nfs_provisioner_version" >> $afile
	printf -v arr_values '"%s",' "${gi_versions[@]}"
        echo "gi_versions: [ ${arr_values%,} ]" >> $afile
	printf -v arr_values '"%s",' "${gi_cases[@]}"
        echo "gi_cases: [ ${arr_values%,} ]" >> $afile
	echo "gi_case_name: $gi_case_name" >> $afile
	echo "gi_case_inventory_setup: $gi_case_inventory_setup" >> $afile
	echo "px_channel: $px_channel" >> $afile
	echo "px_version: $px_version" >> $afile
	echo "cp4s_channel: \"$cp4s_channel\"" >> $afile
	echo "cp4s_case_name: $cp4s_case_name" >> $afile
	echo "cp4s_case_inventory_setup: $cp4s_case_inventory_setup" >> $afile
	printf -v arr_values '"%s",' "${cp4s_cases[@]}"
	echo "cp4s_cases: [ ${arr_values%,} ]" >> $afile
	printf -v arr_values '"%s",' "${cp4s_versions[@]}"
	echo "cp4s_versions: [ ${arr_values%,} ]" >> $afile
	echo "edr_case_name: $edr_case_name" >> $afile
	printf -v arr_values '"%s",' "${edr_cases[@]}"
	echo "edr_cases: [ ${arr_values%,} ]" >> $afile
	echo "edr_case_inventory_setup: $edr_case_inventory_setup" >> $afile
}

function check_exit_code() {
        if [[ $1 -ne 0 ]]
        then
                msg $2 true
                msg "Please check the reason of problem and restart script" true
                echo false
        else
                echo true
        fi
}

function check_input() {
        case $1 in
                "cert")
                        if [ "$2" ]
                        then
                                case $3 in
                                        "ca")
                                                openssl x509 -in "$2" -text -noout &>/dev/null
                                                [[ $? -eq 0 ]] && echo false || echo true
                                                ;;
                                        "app")
                                                openssl verify -CAfile "$4" "$2" &>/dev/null
                                                [[ $? -eq 0 ]] && echo false || echo true
                                                ;;
                                        "key")
                                                openssl rsa -in "$2" -check &>/dev/null
                                                if [[ $? -eq 0 ]]
                                                then
                                                        [[ "$(openssl x509 -noout -modulus -in "$4" 2>/dev/null)" == "$(openssl rsa -noout -modulus -in "$2" 2>/dev/null)" ]] && echo false || echo true
                                                else
                                                        echo true
                                                fi
                                                ;;
                                        "*")
                                                display_error "Incorrect certificate type"
                                                ;;
                                esac
                        else
                                echo true
                        fi
                        ;;
                "cidr")
                        if [[ "$2" =~  ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$ ]]
                        then
                                ( ! $(check_input "ip" `echo "$2"|awk -F'/' '{print $1}'`) && ! $(check_input "int" `echo "$2"|awk -F'/' '{print $2}'` -1 32) ) && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                 "cidr_list")
                        local cidr_arr
                        local cidr
                        if $3 && [ -z "$2" ]
                        then
                                echo false
                        else
                                if [ -z "$2" ] || $(echo "$2" | grep -Eq "[[:space:]]" && echo true || echo false)
                                then
                                        echo true
                                else
                                        local result=false
                                        IFS=',' read -r -a cidr_arr <<< "$2"
                                        for cidr in "${cidr_arr[@]}"
                                        do
                                                check_input "cidr" "$cidr" && result=true
                                        done
                                        echo $result
                                fi
                        fi
                        ;;
		"dir")
                        [ -d "$2" ] && echo false || echo true
                        ;;
                "domain")
                        [[ $2 =~  ^([a-zA-Z0-9](([a-zA-Z0-9-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]] && echo false || echo true
                        ;;
                "dp")
                        [[ $2 == 'D' || $2 == 'P' ]] && echo false || echo true
                        ;;
                "es")
                        [[ $2 == 'E' || $2 == 'S' ]] && echo false || echo true
                        ;;
                "int")
                        if [[ $2 == +([[:digit:]]) ]]
                        then
                                [[ $2 -ge $3 && $2 -le $4 ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "ip")
                        local ip
                        if [[ $2 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
                        then
                                IFS='.' read -r -a ip <<< $2
                                [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
                                [[ $? -eq 0 ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "ips")
                        local ip_value
                        IFS=',' read -r -a master_ip_arr <<< $2
                        if [[ ${#master_ip_arr[@]} -eq $3 && $(printf '%s\n' "${master_ip_arr[@]}"|sort|uniq -d|wc -l) -eq 0 ]]
                        then
                                local is_wrong=false
                                for ip_value in "${master_ip_arr[@]}"
                                do
                                        $(check_input "ip" $ip_value) && is_wrong=true
                                done
                                echo $is_wrong
                        else
                                echo true
                        fi
                        ;;
                "jwt")
                        if [ "$2" ]
                        then
                                { sed 's/\./\n/g' <<< $(cut -d. -f1,2 <<< "$2")|{ base64 --decode 2>/dev/null ;}|jq . ;} 1>/dev/null
                                [[ $? -eq 0 ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "ldap_domain")
                        if [ "$2" ]
                        then
                                [[ "$2" =~ ^([dD][cC]=[a-zA-Z-]{2,64},){1,}[dD][cC]=[a-zA-Z-]{2,64}$ ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "list")
                        if [[ $2 == +([[:digit:]]) ]]
                        then
                                [[ $2 -gt 0 && $2 -le $3 ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
		"mac")
                        [[ $2 =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]] && echo false || echo true
                        ;;
                "macs")
                        local mac_value
                        IFS=',' read -r -a master_mac_arr <<< $2
                        if [[ ${#master_mac_arr[@]} -eq $3 && $(printf '%s\n' "${master_mac_arr[@]}"|sort|uniq -d|wc -l) -eq 0 ]]
                        then
                                local is_wrong=false
                                for mac_value in "${master_mac_arr[@]}"
                                do
                                        $(check_input "mac" $mac_value) && is_wrong=true
                                done
                                echo $is_wrong
                        else
                                echo true
                        fi
                        ;;
                "mail")
                        if [[ "$2" =~ ^.*@.*$ ]]
                        then
                                local m_account=$(echo "$2"|awk -F '@' '{print $1}')
                                local m_domain=$(echo "$2"|awk -F '@' '{print $2}')
                                ! $(check_input "txt" "$m_account" "alphanumeric_max64_chars") && ! $(check_input "domain" "$m_domain") && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "nodes")
                        local element1
                        local element2
                        local i=0
                        local node_arr
                        local selected_arr
                        IFS=',' read -r -a selected_arr <<< "$2"
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
                                                display_error "Incorrect nodes size specification"
                                                ;;
                                esac
                        else
                                echo true
                        fi
                        ;;
		"pe")
                        [[ $2 == 'P' || $2 == 'E' ]] && echo false || echo true
			;;
                "sk")
                        [[ $2 == 'S' || $2 == 'K' ]] && echo false || echo true
                        ;;
                "sto")
                        [[ $2 == 'O' || $2 == 'R' ]] && echo false || echo true
                        ;;
                "stopx")
                        [[ $2 == 'O' || $2 == 'R' || $2 == 'P' ]] && echo false || echo true
                        ;;
                "td")
                        timedatectl set-time "$2" 2>/dev/null
                        [[ $? -eq 0 ]] && echo false || echo true
                        ;;
		"txt")
                        case $3 in
                                "alphanumeric_max64_chars")
                                        [[ $2 =~ ^[a-zA-Z][a-zA-Z0-9]{1,64}$ ]] && echo false || echo true
                                        ;;
                                "non_empty")
                                        [[ ! -z $2 ]] && echo false || echo true
                                        ;;
                                "with_limited_length")
                                        if [ -z "$2" ] || $(echo "$2" | grep -Eq "[[:space:]]" && echo true || echo false)
                                        then
                                                echo true
                                        else
                                                [[ ${#2} -le $4 ]] && echo false || echo true
                                        fi
                                        ;;
                                "*")
                                        display_error "Error"
                                        ;;
                        esac
                        ;;
                "txt_list")
                        local txt_value
                        local txt_arr
                        IFS=',' read -r -a txt_arr <<< $2
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
                        if [[ "$2" =~ ^[a-zA-Z0-9_+-]{1,}/[a-zA-Z0-9_+-]{1,}$ ]]
                        then
                                timedatectl set-timezone "$2" 2>/dev/null
                                [[ $? -eq 0 ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "users_list")
                        local ulist
                        if [ -z "$2" ] || $(echo "$2" | grep -Eq "[[:space:]]" && echo true || echo false)
                        then
                                echo true
                        else
                                local result=false
                                IFS=',' read -r -a ulist <<< "$2"
                                for user in ${ulist[@]}
                                do
                                        [[ "$user" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,}[a-zA-Z0-9]$ ]] || result=true
                                done
                                echo $result
                        fi
                        ;;
                "uuid")
                        [[ "$2" =~ ^\{?[A-Z0-9a-z]{8}-[A-Z0-9a-z]{4}-[A-Z0-9a-z]{4}-[A-Z0-9a-z]{4}-[A-Z0-9a-z]{12}\}?$ ]] && echo false || echo true
                        ;;
                "yn")
                        [[ $2 == 'N' || $2 == 'Y' ]] && echo false || echo true
                        ;;
                *)
                        display_error "Uknown check_input function type"
        esac
}

function check_linux_distribution_and_release() {
        msg "Check OS distribution and release" task
        linux_distribution=`cat /etc/os-release | grep ^ID | awk -F'=' '{print $2}'`
        fedora_release=`cat /etc/os-release | grep VERSION_ID | awk -F'=' '{print $2}'`
        is_supported_fedora_release=`case "${fedora_supp_releases[@]}" in  *"${fedora_release}"*) echo 1 ;; *) echo 0 ;; esac`
        if [ $linux_distribution != 'fedora' ]
        then
                msg "Only Fedora is supported" error
                exit 1
        fi
        if [ $is_supported_fedora_release -eq 0 ]
        then
                msg "Tested Fedora release are ${fedora_supp_releases[*]}, you are using ${fedora_release}" info
		msg "It is suggested to use the tested one. Howeveri, tool should work without problem with your current version. You can update system to the desired release." info
        fi
}

function configure_os_for_proxy() {
	local no_proxy
	local no_proxy_final
        msg "Configuring proxy settings" task
        msg "To support installation over Proxy some additional information must be gathered and reconfiguration of some bastion network services" info
        msg "HTTP Proxy IP address" info
        while $(check_input "ip" "${proxy_ip}")
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
        msg "HTTP Proxy port" info
        while $(check_input "int" "${proxy_port}" 1024 65535)
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
        msg "You can exclude from proxy redirection the access to the intranet subnets" info
        no_proxy_adds="init_value"
        while $(check_input "cidr_list" "${no_proxy_adds}" true)
        do
        	get_input "txt" "Insert comma separated list of CIDRs (like 192.168.0.0/24) which should not be proxied (do not need provide here cluster addresses): " false
                no_proxy_adds="${input_variable}"
        done
	no_proxy="127.0.0.1,*.apps.$ocp_domain,*.$ocp_domain"
	[[ ${#no_proxy_adds} -ne 0 ]] && no_proxy_final="$no_proxy,$no_proxy_adds" || no_proxy_final=$no_proxy
	msg "Your proxy settings are:" info
        msg "Proxy URL: http://$proxy_ip:$proxy_port" info
        msg "System will not use proxy for: $no_proxy_final" info
        msg "Setting your HTTP proxy environment on bastion" info
        msg "Modyfying /etc/profile" info
        [[ -f /etc/profile.gi_no_proxy ]] || cp -f /etc/profile /etc/profile.gi_no_proxy
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
                sed -i "s#^export no_proxy=.*#export no_proxy=\"$no_proxy_final\"#g" /etc/profile
        else
                echo "export no_proxy=\"${no_proxy_final}\"" >> /etc/profile
        fi
        msg "Add proxy settings to DNF config file" info
        [[ -f /etc/dnf/dnf.conf ]] || cp -f /etc/dnf/dnf.conf /etc/dnf/dnf.conf.gi_no_proxy
        if [[ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]]
        then
                sed -i "s/^proxy=.*/proxy=http:\/\/$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
        else
                echo "proxy=http://$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf
        fi
        save_variable GI_NOPROXY_NET "$no_proxy"
        save_variable GI_NOPROXY_NET_ADDS "$no_proxy_adds"
        save_variable GI_PROXY_URL "$proxy_ip:$proxy_port"
}

function create_cluster_ssh_key() {
	local regenerate_ssh_key
        msg "Add a new RSA SSH key" task
	if [[ -f /root/.ssh/cluster_id_rsa.pub ]]
	then
		while $(check_input "yn" "$regenerate_ssh_key" false)
        	do
                        get_input "yn" "There is a ssh key from previous gi-runner execution, would you like to regenerate it? " true
			regenerate_ssh_key=${input_variable^^}
		done
	fi
	if [[ $regenerate_ssh_key == 'Y' ]]
	then
		rm -f /root/.ssh/cluster_id_rsa*
	fi
	if ! [[ -f /root/.ssh/cluster_id_rsa.pub ]]
        then
	        ssh-keygen -N '' -f /root/.ssh/cluster_id_rsa -q <<< y > /dev/null
        	echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > ~/.ssh/config
        	cat /root/.ssh/cluster_id_rsa.pub >> /root/.ssh/authorized_keys
	fi
        	save_variable GI_SSH_KEY "/root/.ssh/cluster_id_rsa"
        	msg "Your SSH keys: /root/.ssh/cluster_id_rsa and /root/.ssh/cluster_id_rsa.pub" info
}

function display_default_ics() {
        local gi_v
        local i=0
        for gi_v in "${gi_versions[@]}"
        do
                msg "ICS - ${ics_versions[${bundled_in_gi_ics_versions[$i]}]} for GI $gi_v" info
                i=$((i+1))
        done
        save_variable GI_ICS_VERSION "${bundled_in_gi_ics_versions[$gi_version_selected]}"
}

function display_error() {
        msg "$1" error
        trap - EXIT
        kill -s TERM $MPID
}

function display_list () {
        local list=("$@")
        local i=1
        for element in "${list[@]}"
        do
                if [[ $i -eq ${#list[@]} ]]
                then
                        msg "    \e[4m$i\e[24m - $element" newline
                else
                        msg "    $i - $element" newline
                fi
                i=$((i+1))
        done
}

function download_file() {
        msg "Downloading $1 ..." info
        wget "$1" &>/dev/null
        test $(check_exit_code $?) || (msg "Cannot download $file" true; exit 1)
}

function get_bastion_info() {
	local bastion_nic
        msg "Collecting data about bastion" task
        msg "If your bastion have two or more network interfaces, provide IP address of the interface which is connected to this same subnet, vlan where the OCP nodes are located" info
        while $(check_input "ip" ${bastion_ip})
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
        msg "Provide the name used to resolve bastion in cluster doman $ocp_domain" info
        while $(check_input "txt" ${bastion_name} "alphanumeric_max64_chars")
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
        if [[ $one_subnet == 'Y' ]]
        then
                msg "Provide the IP gateway of subnet where cluster nodes are located" info
                while $(check_input "ip" ${subnet_gateway})
                do
                        if [[ ! -z "$GI_GATEWAY" ]]
                        then
				get_input "txt" "Insert IP address of the default gateway (press ENTER to confirm previous selection [$GI_GATEWAY]): " true "$GI_GATEWAY"
                        else
                                get_input "txt" "Insert IP address of the default gateway: " false
                        fi
                        subnet_gateway=${input_variable}
                done
                save_variable GI_GATEWAY $subnet_gateway
        fi
	msg "DHCP server will be deployed on bastion. You must provide the bastion network interface specification on which the service would listen." info
	while $(check_input "txt" "${bastion_nic}" "non_empty")
        do
                if [ ! -z "$GI_BASTION_INTERFACE" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_BASTION_INTERFACE] or insert NIC specification: " true "$GI_BASTION_INTERFACE"
                else
                        get_input "txt" "Insert NIC specification for DHCP service on bastion: " false
                fi
                bastion_nic="${input_variable}"
        done
        save_variable GI_BASTION_INTERFACE "$bastion_nic"
}

function get_certificates() {
        [[ "$use_air_gap" == 'N' ]] && { msg "Installing openssl ..." info; dnf -y install openssl > /dev/null; }
        msg "Collecting certificates information" task
        msg "You can replace self-signed certicates for UI's by providing your own created by trusted CA" info
        msg "Certificates must be uploaded to bastion to provide full path to them" info
        msg "CA cert, service cert and private key files must be stored separately in PEM format" info
        while $(check_input "yn" "$ocp_ext_ingress" false)
        do
		if [[ ! -z "$GI_OCP_IN" ]]
		then
			get_input "yn" "Would you like to install own certificates for OCP (or press ENTER to select the previous choice [$GI_OCP_IN]) " false $GI_OCP_IN
		else
                	get_input "yn" "Would you like to install own certificates for OCP?: " true
		fi
                ocp_ext_ingress=${input_variable^^}
        done
        save_variable GI_OCP_IN $ocp_ext_ingress
        [ $ocp_ext_ingress == 'Y' ] && validate_certs "ocp"
        if [[ "$gi_install" == 'Y' || "$ics_install" == 'Y' ]]
        then
                while $(check_input "yn" "$ics_ext_ingress" false)
                do
			if [[ ! -z "$GI_ICS_IN" ]]
                	then
                        	get_input "yn" "Would you like to install own certificates for CPFS (or press ENTER to select the previous choice [$GI_ICS_IN]) " false $GI_ICS_IN
			else
                        	get_input "yn" "Would you like to install own certificates for CPFS?: " true
			fi
                        ics_ext_ingress=${input_variable^^}
                done
                save_variable GI_ICS_IN $ics_ext_ingress
                [ $ics_ext_ingress == 'Y' ] && validate_certs "ics"
        fi
        if [[ "$gi_install" == 'Y' ]]
        then
                while $(check_input "yn" "$gi_ext_ingress" false)
                do
			if [[ ! -z "$GI_IN" ]]
                        then
                                get_input "yn" "Would you like to install own certificates for GI (or press ENTER to select the previous choice [$GI_IN]) " false $GI_IN
			else
                        	get_input "yn" "Would you like to install own certificates for GI?: " true
			fi
                        gi_ext_ingress=${input_variable^^}
                done
                save_variable GI_IN $gi_ext_ingress
                [ $gi_ext_ingress == 'Y' ] && validate_certs "gi"
        fi
        if [[ "$cp4s_install" == 'Y' ]]
        then
                while $(check_input "yn" "$cp4s_ext_ingress" false)
                do
			if [[ ! -z "$GI_CP4S_IN" ]]
                        then
                                get_input "yn" "Would you like to install own certificates for CP4S (or press ENTER to select the previous choice [$GI_CP4S_IN]) " false $GI_CP4S_IN
			else
                        	get_input "yn" "Would you like to install own certificates for CP4S?: " true
			fi
                        cp4s_ext_ingress=${input_variable^^}
                done
                save_variable GI_CP4S_IN $cp4s_ext_ingress
                [ $cp4s_ext_ingress == 'Y' ] && validate_certs "cp4s"
        fi
	if [[ "$edr_install" == 'Y' ]]
        then
                while $(check_input "yn" "$edr_ext_ingress" false)
                do
                        if [[ ! -z "$GI_EDR_IN" ]]
                        then
                                get_input "yn" "Would you like to install own certificates for EDR (or press ENTER to select the previous choice [$GI_EDR_IN]) " false $GI_EDR_IN
                        else
                                get_input "yn" "Would you like to install own certificates for EDR?: " true
                        fi
                        edr_ext_ingress=${input_variable^^}
                done
                save_variable GI_EDR_IN $edr_ext_ingress
                [ $edr_ext_ingress == 'Y' ] && validate_certs "edr"
        fi
}

function get_cluster_storage_info() {
        msg "Cluster storage information" task
        msg "There is assumption that all storage cluster node use this same device specification for storage disk" info
        msg "In most cases the second boot disk will have specification \"sdb\" or \"nvmne1\"" info
        msg "The inserted value refers to root path located in /dev" info
        msg "It means that value sdb refers to /dev/sdb" info
        while $(check_input "txt" "${storage_device}" "non_empty")
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
        msg "Cluster storage devices ($storage_device)  must be this same size on all storage nodes!" info
        msg "The minimum size of each disk is 100 GB" info
        while $(check_input "int" "${storage_device_size}" 100 10000000)
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
        [[ "$storage_type" == 'P' ]] && get_px_options
}

function get_cp4s_options() {
        msg "Collecting CP4S deployment parameters" task
        if [ $use_air_gap == 'Y' ]
        then
                msg "CP4S requires access to some Internet sites. In case of air-gapped installation access must be provided using proxy" info
                msg "List of sites is available at: https://www.ibm.com/docs/en/cp-security/1.10?topic=environment-creating-allowlist-air-gapped-installation" info
                msg "HTTP Proxy server address" info
                while $(check_input "ip" "${proxy_ip}")
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
                msg "HTTP Proxy port" info
                while $(check_input "int" "${proxy_port}" 1024 65535)
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
                msg "You can exclude from proxy redirection the access to the intranet subnets" info
                no_proxy_adds="init_value"
                while $(check_input "cidr_list" "${no_proxy_adds}" true)
                do
                        get_input "txt" "Insert comma separated list of CIDRs (like 192.168.0.0/24) which should not be proxied (do not need provide here cluster addresses): " false
                        no_proxy_adds="${input_variable}"
                done
                no_proxy="127.0.0.1,*.apps.$ocp_domain,*.$ocp_domain,$no_proxy_adds"
                save_variable GI_NOPROXY_NET "$no_proxy"
                save_variable GI_NOPROXY_NET_ADDS "$no_proxy_adds"
                save_variable GI_PROXY_URL "$proxy_ip:$proxy_port"
        fi
        msg "Namespace defines the space where most CP4S pods, objects and supporting services will be located" info
        while $(check_input "txt" "${cp4s_namespace}" "with_limited_length" 10)
        do
                if [ ! -z "$GI_CP4S_NS" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_CP4S_NS] or insert GI namespace name (maximum 10 characters)" true "$GI_CP4S_NS"
                else
                        get_input "txt" "Insert CP4S namespace name (maximum 10 characters, default cp4s): " true "cp4s"
                fi
                cp4s_namespace="${input_variable}"
        done
        save_variable GI_CP4S_NS $cp4s_namespace
	msg "Enter the name of the directory service account to which the role of privilege administrator will be attached?" info
        [ $install_ldap == 'Y' ] && msg "Because the OpenLDAP will be installed in this procedure the pointed account will be created automatically during LDAP deployment." info
        while $(check_input "txt" "${cp4s_admin}" "non_empty")
        do
                if [ ! -z "$GI_CP4S_ADMIN" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_CP4S_ADMIN] or insert CP4S admin username: " true "$GI_CP4S_ADMIN"
                else
                        get_input "txt" "Insert CP4S admin username (default - cp4sadmin): " true "cp4sadmin"
                fi
                cp4s_admin="${input_variable}"
        done
        save_variable GI_CP4S_ADMIN "$cp4s_admin"
        msg "Default storage class for CP4S." info
        msg "All CP4S PVC's use RWO access." info
        [ $storage_type == 'R' ] && sc_list=(${rook_sc[@]}) || sc_list=(${ocs_sc[@]})
	if [ $storage_type == 'R' ]
	then
        	while $(check_input "list" ${cp4s_sc_selected} ${#sc_list[@]})
        	do
                	get_input "list" "Select storage class: " "${sc_list[@]}"
                	cp4s_sc_selected=$input_variable
        	done
        	cp4s_sc="${sc_list[$((${cp4s_sc_selected} - 1))]}"
        	save_variable GI_CP4S_SC $cp4s_sc
	elif [ $storage_type == 'O' ]
	then
		save_variable GI_CP4S_SC "ocs-storagecluster-ceph-rbd"
	else
		save_variable GI_CP4S_SC "portworx-db2-rwo-sc"
	fi
        msg "Enter default storage class for CP4S backup, it uses RWO access." info
	if [ $storage_type == 'R' ]
        then
	        while $(check_input "list" ${cp4s_sc_backup_selected} ${#sc_list[@]})
        	do
                	get_input "list" "Select storage class: " "${sc_list[@]}"
                	cp4s_sc_backup_selected=$input_variable
        	done
        	cp4s_sc_backup="${sc_list[$((${cp4s_sc_backup_selected} - 1))]}"
        	save_variable GI_CP4S_SC_BACKUP $cp4s_sc_backup
	elif [ $storage_type == 'O' ]
        then
                save_variable GI_CP4S_SC_BACKUP "ocs-storagecluster-ceph-rbd"
        else
                save_variable GI_CP4S_SC_BACKUP "portworx-db2-rwo-sc"
        fi
        msg "Enter the backup PVC size for CP4S. Minimum and default value 500 GB" info
        while $(check_input "int" "$cp4s_backup_size" 499 999999)
        do
                if [ ! -z "$GI_CP4S_BACKUP_SIZE" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [${GI_CP4S_BACKUP_SIZE}] or insert size of backup PVC (in GB): " true "$GI_CP4S_BACKUP_SIZE"
                else
                        get_input "txt" "Insert size of backup PVC or press <ENTER> to set default value [500] (in GB): " true 500
                fi
                cp4s_backup_size="${input_variable}"
        done
        save_variable GI_CP4S_BACKUP_SIZE $cp4s_backup_size
        msg "Some CP4S functions can be installed optionally, select desired ones." info
        local cp4s_features=("Detection_and_Response_Center,Y" "Security_Risk_Manager,Y" "Thread_Investigator,Y")
        declare -a cp4s_opts
        for opt in ${cp4s_features[@]}
        do
                unset op_option
                IFS="," read -r -a curr_op <<< $opt
                while $(check_input "yn" "$op_option")
                do
                        get_input "yn"  "Would you like to install ${curr_op[0]//_/ } application: " $([[ "${curr_op[1]}" != 'Y' ]] && echo true || echo false)
                        op_option=${input_variable^^}
                done
                cp4s_opts+=($op_option)
        done
	save_variable GI_CP4S_OPTS $(printf "%s,${cp4s_opts[@]}")
}

function get_credentials() {
        local is_ok
        msg "Collecting all required credentials" task
        local is_ok=true #there is no possibility to send variable with unescaped json
        if [ $use_air_gap == 'N' ]
        then
                msg "Non air-gapped OCP installations requires access to remote image registries located in the Internet" info
                msg "Access to OCP images is restricted and requires authorization using RedHat account pull secret" info
                msg "You can get access to your pull secret at this URL - https://cloud.redhat.com/openshift/install/local" info
                while $is_ok
                do
                        if [ ! -z "$GI_RHN_SECRET" ]
                        then
                                msg "Push <ENTER> to accept the previous choice" newline
                                msg "[$GI_RHN_SECRET]" newline
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
                if [[ $gi_install == 'Y' || $cp4s_install == 'Y' || $edr_install == 'Y' ]]
                then
                        msg "GI, CP4S and EDR require access to restricted IBM image registries" info
                        msg "You need to insert the IBM Cloud containers key located at URL - https://myibm.ibm.com/products-services/containerlibrary" info
                        msg "Your account must be entitled to install Cloud Pak like Guardium Insights, Cloud Pak for Security, Qradar EDR" info
                        while $(check_input "jwt" "${ibm_secret}")
                        do
                                if [ ! -z "$GI_IBM_SECRET" ]
                                then
                                        msg "Push <ENTER> to accept the previous choice" newline
                                        msg "[$GI_IBM_SECRET]" newline
                                        get_input "txt" "or insert IBM Cloud container key: " true "$GI_IBM_SECRET"
                                else
                                        get_input "txt" "Insert IBM Cloud container key: " false
                                fi
                                ibm_secret="${input_variable}"
                        done
                        save_variable GI_IBM_SECRET "'$ibm_secret'"
                fi
        fi
	msg "Define user name and password of an additional OpenShift administrator" info
        while $(check_input "txt" "${ocp_admin}" "non_empty")
        do
                if [ ! -z "$GI_OCADMIN" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_OCADMIN] or insert OCP admin username: " true "$GI_OCADMIN"
                else
                        get_input "txt" "Insert OCP admin username (default - ocpadmin): " true "ocpadmin"
                fi
                ocp_admin="${input_variable}"
        done
        save_variable GI_OCADMIN "$ocp_admin"
        while $(check_input "txt" "${ocp_password}" "non_empty")
        do
                if [ ! -z "$GI_OCADMIN_PWD" ]
                then
                        get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_OCADMIN_PWD] or insert OCP $ocp_admin user password: " true "$GI_OCADMIN_PWD"
                else
                        get_input "pwd" "Insert OCP $ocp_admin user password: " false
                fi
                ocp_password="${input_variable}"
        done
        save_variable GI_OCADMIN_PWD "'$curr_password'"
        if [[ "$gi_install" == 'Y' || "$ics_install" == 'Y' || "$cp4s_install" == 'Y' ]]
        then
                msg "Define CPFS admin user password" info
                msg "This same account is used by GI for default account with access management role" info
                while $(check_input "txt" "${ics_password}" "non_empty")
                do
                        if [ ! -z "$GI_ICSADMIN_PWD" ]
                        then
                                get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_ICSADMIN_PWD] or insert CPFS admin user password: " true "$GI_ICSADMIN_PWD"
                        else
                                get_input "pwd" "Insert CPFS admin user password: " false
                        fi
                        ics_password="${input_variable}"
                done
                save_variable GI_ICSADMIN_PWD "'$curr_password'"
        fi
        if [[ "$install_ldap" == 'Y' ]]
        then
                msg "Define LDAP users initial password" info
                while $(check_input "txt" "${ldap_password}" "non_empty")
                do
                        if [ ! -z "$GI_LDAP_USERS_PWD" ]
                        then
                                get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_LDAP_USERS_PWD] or insert default LDAP users password: " true "$GI_LDAP_USERS_PWD"
                        else
                                get_input "pwd" "Insert default LDAP users password: " false
                        fi
                        ldap_password="${input_variable}"
                done
                save_variable GI_LDAP_USERS_PWD "'$curr_password'"
        fi
}

function get_edr_options {
	msg "Collecting EDR information" task
	msg "Namespace defines the space where most EDR pods, objects and supporting services will be located" info
        while $(check_input "txt" "${edr_namespace}" "with_limited_length" 10)
        do
                if [ ! -z "$GI_EDR_NS" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_EDR_NS] or insert EDR namespace name (maximum 10 characters)" true "$GI_EDR_NS"
                else
                        get_input "txt" "Insert EDR namespace name (maximum 10 characters, default edr): " true "edr"
                fi
                edr_namespace="${input_variable}"
        done
        save_variable GI_EDR_NS $edr_namespace
	msg "License types: Pro and Enterprise, the second one includes EDR API and Detection Strategies functionality" info
	while $(check_input "pe" "${edr_license}")
        do
                if [ ! -z "$GI_EDR_LICENSE" ]
                then
			get_input "txt" "Push <ENTER> to accept the previous choice [$GI_EDR_LICENSE] or select license type (P)ro or (E)nteprise: " true "$GI_EDR_LICENSE"
                else
			get_input "txt" "Select license type (P)ro or (\e[4mE\e[0m)nterprise: " true "E"
                fi
                edr_license="${input_variable^^}"
        done
        save_variable GI_EDR_LICENSE $edr_license

}

function get_gi_options() {
        local change_ssh_host
	local gi_backup_active
        msg "Collecting Guardium Insights parameters" task
        msg "Guardium Insights deployment requires some decisions such as storage size, functions enabled" info
        msg "Namespace define the space where most GI pods, objects and supporting services will be located" info
        while $(check_input "txt" "${gi_namespace}" "with_limited_length" 10)
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
        while $(check_input "yn" "$db2_enc" false)
        do
		if [ ! -z "$GI_DB2_ENCRYPTED" ]
                then
                	get_input "yn" "Should be DB2u tablespace encrypted or accept previous choice [$GI_DB2_ENCRYPTED]? " true $GI_DB2_ENCRYPTED
		else
                	get_input "yn" "Should be DB2u tablespace encrypted? " true
		fi
                db2_enc=${input_variable^^}
        done
        save_variable GI_DB2_ENCRYPTED $db2_enc
        while $(check_input "yn" "$stap_supp" false)
        do
		if [ ! -z "$GI_STAP_STREAMING" ]
                then
                	get_input "yn" "Should be enabled the direct streaming from STAP's and Outliers engine, press ENTER to accept previous decision [$GI_STAP_STREAMING]? " false $GI_STAP_STREAMING
		else
                	get_input "yn" "Should be enabled the direct streaming from STAP's and Outliers engine?: " false
		fi
                stap_supp=${input_variable^^}
        done
        save_variable GI_STAP_STREAMING $stap_supp
	msg "DB2 growth have some limitations related to unchangeable number of partitions. You must define the total number of partition in DB2 cluster at the beginning. Then you can add more DB2 nodes but the number partition cannot be changed" info
	msg "For example, if deployed initially 10 partitions on two DB2 nodes (5 partitions per node) then you can extend cluster to have 5 DB2 nodes (2 partition per node) or 10 DB2 nodes (1 partition per node)" info
	msg "1 partition should not server more that 5 TB of data, so in this example the total DB2 data storage should not exceed 50 TB" info
	while $(check_input "int" "$partition_per_node" 1 10)
        do
                if [ ! -z "$GI_DB2_PARTITION_PER_NODE" ]
                then
                        get_input "int" "How many partitions per node should be deployed in DB2 cluster, press ENTER to accept previous selection [$GI_DB2_PARTITION_PER_NODE]? " false $GI_DB2_PARTITION_PER_NODE
                else
			get_input "int" "How many partitions per node should be deployed in DB2 cluster (default 1)?: " false 1
                fi
                partition_per_node=${input_variable}
        done
        save_variable GI_DB2_PARTITION_PER_NODE $partition_per_node
        while $(check_input "yn" "$outliers_demo" false)
        do
		if [ ! -z "$GI_OUTLIERS_DEMO" ]
                then
                	get_input "yn" "Should the Outliers engine work in demo mode, press ENTER to accept previous selection [$GI_OUTLIERS_DEMO]? " false $GI_OUTLIERS_DEMO
		else
                	get_input "yn" "Should the Outliers engine work in demo mode?: " false
		fi
                outliers_demo=${input_variable^^}
        done
        save_variable GI_OUTLIERS_DEMO $outliers_demo
        get_gi_pvc_size
        msg "GDP integration" task
        msg "One of the method to send events to Guardium is integration with Guardium Data Protection" info
        msg "In this case the selected collectors will transfer to GI audited events by copying datamarts to GI ssh service" info
        msg "As a default the collector sends data to cluster proxy on bastion using random port range 30000-32768" info
        while $(check_input "yn" "$change_ssh_host" false)
        do
                get_input "yn" "Would you like to send datamarts using another proxy server?: " true
                change_ssh_host=${input_variable^^}
        done
        if [[ $change_ssh_host == 'Y' ]]
        then
                while $(check_input "ip" $ssh_host)
                do
			if [ ! -z "$GI_SSH_HOST" ]
                	then
                        	get_input "txt" "Insert IP address of Load Balancer to which datamarts should be redirected or press ENTER to accept previous choice [$GI_SSH_HOST]: " false $GI_SSH_HOST
			else
                        	get_input "txt" "Insert IP address of Load Balancer to which datamarts should be redirected: " false
			fi
                        ssh_host=${input_variable}
                done
                save_variable GI_SSH_HOST $ssh_host
        else
                save_variable GI_SSH_HOST "0.0.0.0"
        fi
        msg "You can define static port on load balancer to send datamarts" info
        msg "ssh port change is managed automatically on HA Proxy on bastion, in case of use the separate appliance you must provide the port defined on it" info
        while $(check_input "yn" "$change_ssh_port" false)
        do
                get_input "yn" "Would you like to set ssh port used to send datamarts?: " true
                change_ssh_port=${input_variable^^}
        done
        if [[ $change_ssh_port == 'Y' ]]
        then
                while $(check_input "int" $ssh_port 1024 65635)
                do
			if [ ! -z "$GI_SSH_PORT" ]
                        then
                        	get_input "txt" "Insert port number used on Load Balancer to transfer datamarts to GI or press ENTER to select previously selected [$GI_SSH_PORT]: " true $GI_SSH_PORT
			else
                        	get_input "txt" "Insert port number used on Load Balancer to transfer datamarts to GI: " true
			fi
                        ssh_port=${input_variable}
                done
                save_variable GI_SSH_PORT $ssh_port
        else
                save_variable GI_SSH_PORT "0"
        fi
        msg "GI Backup configuration" task
        msg "There is possible to use NFS based storage for GI backups" info
        while $(check_input "yn" "$use_nfs_backup" false)
        do
		if [ ! -z "$GI_NFS_BACKUP" ]
                then
                	get_input "yn" "Would you like to configure GI backups using NFS storage or press ENTER to select previous decision [$GI_NFS_BACKUP]? " true $GI_NFS_BACKUP
		else
                	get_input "yn" "Would you like to configure GI backups using NFS storage? " true
		fi
                use_nfs_backup=${input_variable^^}
        done
        save_variable GI_NFS_BACKUP $use_nfs_backup
	gi_backup_active='N'
        if [[ $use_nfs_backup == 'Y' ]]
        then
                while $(check_input "ip" $nfs_server)
                do
                        if [ ! -z "$GI_NFS_SERVER" ]
                        then
                                get_input "txt" "Push <ENTER> to accept previously pointed NFS server - [$GI_NFS_SERVER] or insert a new address: " true "$GI_NFS_SERVER"
                        else
                                get_input "txt" "Insert IP address of NFS server: " false
                        fi
                        nfs_server=${input_variable}
                done
                save_variable GI_NFS_SERVER $nfs_server
                while $(check_input "txt" $nfs_path "non_empty")
                do
                        if [ ! -z "$GI_NFS_PATH" ]
                        then
                                get_input "txt" "Push <ENTER> to accept NFS share path for backup - [$GI_NFS_PATH] or insert another NFS server path: " true "$GI_NFS_PATH"
                        else
                                get_input "txt" "Insert NFS server path: " false
                        fi
                        nfs_path=${input_variable}
                done
                save_variable GI_NFS_PATH $nfs_path
		gi_backup_active='Y'
        fi
	if [[ $gi_backup_active == 'Y' ]]
	msg "Backup PVC will be created during GI deployment, you must provide its size (in GiB) - minimum 100 Gi" info
        then
		while $(check_input "int" $gi_backup_volume_size 100 100000)
                do
                        if [ ! -z "$GI_BACKUP_SIZE" ]
                        then
                                get_input "int" "Insert size of backup volume (in gibibytes) or press <ENTER> to accept previous value [$GI_BACKUP_SIZE]: " false "$GI_BACKUP_SIZE"
                        else
				get_input "int" "Insert size of backup volume (in gibibytes): " false
                        fi
                        gi_backup_volume_size=${input_variable}
                done
                save_variable GI_BACKUP_SIZE $gi_backup_volume_size
	fi
}

function get_gi_pvc_size() {
        local custom_pvc
        msg "The cluster storage contains 3 disks - ${storage_device_size} GB each" info
        [[ "$storage_type" == 'O' ]] && msg "ODF creates 3 copies of data chunks so you have ${storage_device_size} of GB effective space for PVC's" info || msg "Rook-Ceph creates 2 copies of data chunks so you have $((2*${storage_device_size})) GB effective space for PVC's" info
        while $(check_input "yn" "$custom_pvc")
        do
                get_input "yn" "Would you like customize Guardium Insights PVC sizes (default) or use default settings?: " false
                custom_pvc=${input_variable^^}
        done
        if [ $custom_pvc == 'Y' ]
        then
                pvc_arr=("db2-data" "db2-meta" "db2-logs" "db2-temp" "mongo-data" "mongo-logs" "kafka" "zookeeper" "redis" "pgsql" "noobaa-core" "noobaa-backing")
                for pvc in ${pvc_arr[@]};do pvc_sizes $pvc;done
        else
                local pvc_variables=("GI_DATA_STORAGE_SIZE" "GI_METADATA_STORAGE_SIZE" "GI_ARCHIVELOGS_STORAGE_SIZE" "GI_TEMPTS_STORAGE_SIZE" "GI_MONGO_DATA_STORAGE_SIZE" "GI_MONGO_METADATA_STORAGE_SIZE" "GI_KAFKA_STORAGE_SIZE" "GI_ZOOKEEPER_STORAGE_SIZE" "GI_REDIS_STORAGE_SIZE" "GI_POSTGRES_STORAGE_SIZE" "GI_NOOBAA_CORE_SIZE" "GI_NOOBAA_BACKING_SIZE")
                for pvc in ${pvc_variables[@]};do save_variable $pvc 0;done
        fi
}

function get_hardware_info() {
        msg "Collecting hardware information" task
        msg "Automatic CoreOS and storage deployment requires information about NIC and storage devices" info
        msg "There is assumption that all cluster nodes including bootstrap machine use this same HW specification for network and storage" info
        #msg "The Network Interface Card (NIC) device specification must provide the one of the interfaces attached to cluster subnet" info
        #msg "In most cases the first NIC attached to machine will have on Fedora and RedHat the name \"ens192\"" info
        #while $(check_input "txt" "${machine_nic}" "non_empty")
        #do
        #        if [ ! -z "$GI_NETWORK_INTERFACE" ]
        #        then
        #                get_input "txt" "Push <ENTER> to accept the previous choice [$GI_NETWORK_INTERFACE] or insert NIC specification: " true "$GI_NETWORK_INTERFACE"
        #        else
        #                get_input "txt" "Insert NIC specification: " false
        #        fi
        #        machine_nic="${input_variable}"
        #done
        #save_variable GI_NETWORK_INTERFACE "$machine_nic"
        msg "There is assumption that all cluster machines use this device specification for boot disk" info
        msg "In most cases the first boot disk will have specification \"sda\" or \"nvmne0\"" info
	msg "The inserted value refers to device located in /dev directory (it means that value sda refers to /dev/sda)" info
        while $(check_input "txt" "${machine_disk}" "non_empty")
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
	msg "All your nodes have the NIC ${machine_nic} attached to cluster subnet/subnets. All your nodes use /dev/${machine_disk} as a boot disk." info
}

function get_ics_options() {
	msg "Collecting IBM Cloud Pak Foundational Services (CPFS) - former Common Services - parameters" task
        local operand
        local curr_op
	local cpfs_sizes
	local cpfs_size
	cpfs_sizes=("large" "medium" "small" "starterset")
	msg "CPFS can be deployed in the 4 different service redundancies configuration: starterset, small, medium and large" info
	msg "Use small or starterset deployment for test and demo Cloud Pak systems, medium for production deployment and large (minimum 5 workers needed) if you really require high performance and redundancy" info
	while $(check_input "list" ${cpfs_size} ${#cpfs_sizes[@]})
        do
                get_input "list" "Select CPFS size deployment: " ${cpfs_sizes[@]}
                cpfs_size=$input_variable
        done
	[[ $cpfs_size -eq 1 ]] && cpfs_size='L' || [[ $cpfs_size -eq 2 ]] && cpfs_size='M' || [[ $cpfs_size -eq 3 ]] && cpfs_size='S' || cpfs_size='T'
        save_variable GI_CPFS_SIZE $cpfs_size
        msg "CPFS provides possibility to define which services will be deployed, some of them are required by CP4S, EDR and GI and will installed as default, the others are optional." info
        msg "These operands will be installed as default:" info
        msg "- Certificate Manager" info
        msg "- Healthcheck" info
        msg "- IBM IAM" info
        msg "- Management ingress" info
        msg "- Licensing" info
        msg "- ICS Common UI" info
        msg "- Platform API" info
        msg "- IBM Events" info
        msg "- Audit Logging" info
        msg "- MongoDB" info
        msg "Define additional operands to install:" info
        local operand_list=("Monitoring,Y" "Zen,N" "DB2,N" "Postgres,N" "User_Data_Services,N" "Business_Teams,N")
        declare -a ics_ops
        for operand in ${operand_list[@]}
        do
                unset op_option
                IFS="," read -r -a curr_op <<< $operand
                while $(check_input "yn" "$op_option")
                do
                        get_input "yn"  "Would you like to install ${curr_op[0]//_/ } operand: " $([[ "${curr_op[1]}" != 'Y' ]] && echo true || echo false)
                        op_option=${input_variable^^}
                done
                ics_ops+=($op_option)
        done
        save_variable GI_ICS_OPERANDS $(echo ${ics_ops[@]}|awk 'BEGIN { FS= " ";OFS="," } { $1=$1 } 1')
}

function get_input() {
        unset input_variable
        msg "$2" monit
        case $1 in
                "dp")
                        read input_variable
                        $3 && input_variable=${input_variable:-D} || input_variable=${input_variable:-P}
                        ;;
                "es")
                        read input_variable
                        $3 && input_variable=${input_variable:-S} || input_variable=${input_variable:-E}
                        ;;
                "int")
                        read input_variable
			if [[ $# -eq 4 ]]
			then
				[[ $input_variable == '' ]] && input_variable=$4
			fi
                        ;;
                "list")
                        msg "" newline
                        shift
                        shift
                        local list=("$@")
                        display_list $@
                        msg "Your choice: " continue
                        read input_variable
                        input_variable=${input_variable:-${#list[@]}}
                        ;;
                "pwd")
                        local password=""
                        local password2=""
                        read -s -p "" password
                        echo
                        if [ "$password" == "" ] && $3
                        then
                                curr_password="$4";input_variable=false
                        else
                                if [ "$password" == "" ]
                                then
                                        input_variable=true
                                else
                                        read -s -p ">>> Insert password again: " password2
                                        echo
                                        if [ "$password" == "$password2" ]
                                        then
                                                curr_password=$password
                                                input_variable=false
                                        else
                                                msg "Please try again" newline
                                                input_variable=true
                                        fi
                                fi
                        fi
                        ;;
                "sk")
                        read input_variable
                        $3 && input_variable=${input_variable:-K} || input_variable=${input_variable:-S}
                        ;;
                "stopx")
	                read input_variable
			if [[ $# -eq 4 && $input_variable == '' ]]
			then
	                	input_variable=$4        
			fi
        	        input_variable=${input_variable^^}
                        ;;
		"txt")
                        read input_variable
                        if $3
                        then
                                [ -z ${input_variable} ] && input_variable="$4"
                        fi
                        ;;
                "yn")
			if [[ $# -eq 4 ]]
			then
				msg "(N)o/(Y)es: " continue
				read input_variable
				printf "\e[0m"
				[[ $input_variable == '' ]] && input_variable=$4
			else
                       		$3 && msg "(\e[4mN\e[24m)o/(Y)es: " continue || msg "(N)o/(\e[4mY\e[24m)es: " continue
                       		read input_variable
                       		printf "\e[0m"
                        	$3 && input_variable=${input_variable:-N} || input_variable=${input_variable:-Y}
			fi
                        ;;
                *)
                        display_error "Unknown get_input function type"
        esac
}

function get_inter_cluster_info() {
        msg "CNI plug-in selection" task
        while $(check_input "sk" ${ocp_cni})
        do
                get_input "sk" "Would you like use default CNI plug-in from OCP 4.12 - OVN[K]ubernetes or OpenShift[S]DN (\e[4mK\e[0m)/S): " true
                ocp_cni=${input_variable^^}
        done
        save_variable GI_OCP_CNI $ocp_cni
        msg "Inter-node cluster pod communication" task
        msg "Pods in cluster communicate with one another using private network, use non-default values only if your physical network use IP address space 10.128.0.0/16" info
        while $(check_input "cidr" "${ocp_cidr}")
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
        msg "Each pod will reserve IP address range from subnet $ocp_cidr, provide this range using subnet mask (must be higher than $cidr_subnet)" info
        while $(check_input "int" "${ocp_cidr_mask}" $cidr_subnet 27)
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

function get_ldap_options() {
        msg "Collecting OpenLDAP deployment parameters" task
        msg "Define LDAP domain distinguished name, only DC components are allowed like dc=test,dc=com" info
        while $(check_input "ldap_domain" "${ldap_domain}")
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
	msg "Provide list of users which will be created in OpenLDAP instance" info
        while $(check_input "users_list" "${ldap_users}" )
        do
                if [ ! -z "$GI_LDAP_USERS" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_LDAP_USERS] or insert comma separated list of LDAP users (without spaces): " true "$GI_LDAP_USERS"
                else
                        get_input "txt" "Insert comma separated list of LDAP users (without spaces): " false
                fi
                ldap_users="${input_variable}"
        done
        # avoid repetition accounts in LDAP
        if [[ $cp4s_install == 'Y' ]]
        then
                IFS="," read -r -a ldap_users <<< $ldap_users
                ldap_users+=($cp4s_admin)
                IFS=" " read -r -a ldap_users <<< "$(tr ' ' '\n' <<< "${ldap_users[@]}" | sort -u | tr '\n' ' ')"
                local IFS=,
                ldap_users=`echo "${ldap_users[*]}"`
        fi
        save_variable GI_LDAP_USERS "'$ldap_users'"
}

function get_network_architecture {
        msg "Network subnet assignment for OCP nodes" task
        msg "OpenShift cluster nodes can be located in the different subnets" info
        msg "If you plan to place individual nodes in separate subnets it is necessary to ensure that DHCP requests are forwarded to the bastion ($bastion_ip) using DHCP relay" info
        msg "It is also recommended to place the bastion outside the subnets used by the cluster" info
        msg "If you cannot setup DHCP relay in your network, all cluster nodes and bastion must be located in this same subnet (DHCP broadcast network)" info
        while $(check_input "yn" "$one_subnet")
        do
		if [[ ! -z "$GI_ONE_SUBNET" ]]
		then
			get_input "yn" "Would you like to place the cluster nodes in one subnet (or press ENTER to select the previous choice [$GI_ONE_SUBNET]) " false $GI_ONE_SUBNET
		else
                	get_input "yn"  "Would you like to place the cluster nodes in one subnet?: " false
		fi
                one_subnet=${input_variable^^}
        done
        save_variable GI_ONE_SUBNET $one_subnet
}

function get_network_installation_type() {
	msg "You can deploy OCP with (direct or proxy) or without (named as air-gapped, offline, disconnected) access to the internet" info
        while $(check_input "yn" ${use_air_gap})
        do
                get_input "yn" "Is your environment air-gapped? - " true
                use_air_gap=${input_variable^^}
        done
        if [ $use_air_gap == 'Y' ]
        then
		msg "Air-gapped installation requires some preparation steps." info
		msg "You should download images and tools first and then start deployment." info
	 	while $(check_input "yn" "$is_air_prepared")
		do
			get_input "yn" "Did you collect images and tools using prepare_offline.sh script: " false "Y"
			is_air_prepared=${input_variable^^}
		done
		[[ $is_air_prepared == 'N' ]] && { msg "Collect images and tools before, execute prepare_offline.sh script" info; exit 0; }
                switch_dnf_sync_off
                save_variable GI_INTERNET_ACCESS "A"
        else
                while $(check_input "dp" ${use_proxy})
                do
                        get_input "dp" "Has your environment direct access to the internet or use HTTP proxy? (\e[4mD\e[0m)irect/(P)roxy: " true
                        use_proxy=${input_variable^^}
                done
                save_variable GI_INTERNET_ACCESS $use_proxy
        fi
}

function get_nodes_info() {
        local temp_ip
        local temp_mac
        local temp_name
        case $2 in
                "ocs")
                        local pl_names=("addresses" "names" "IP's" "hosts")
                        local node_type="ODF nodes"
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
                        display_error "Incorrect parameters get_nodes_info function"
        esac
	msg "Insert $1 ${pl_names[2]} ${pl_names[0]} of $node_type, should be located in subnet with gateway - $subnet_gateway" info
        while $(check_input "ips" ${temp_ip} $1)
        do
                if [ ! -z "$global_var_ip" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_ip] or insert $node_type ${pl_names[2]}: " true "$global_var_ip"
                else
                        get_input "txt" "Insert $node_type IP: " false
                fi
                temp_ip=${input_variable}
        done
        msg "Insert $1 MAC ${pl_names[0]} of $node_type" info
        while $(check_input "macs" ${temp_mac} $1)
        do
                if [ ! -z "$global_var_mac" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_mac] or insert $node_type MAC ${pl_names[0]}: " true "$global_var_mac"
                else
                        get_input "txt" "Insert $node_type MAC ${pl_names[0]}: " false
                fi
                temp_mac=${input_variable}
        done
        msg "Insert $1 ${pl_names[3]} ${pl_names[1]} of $node_type" info
        while $(check_input "txt_list" ${temp_name} $1)
        do
                if [ ! -z "$global_var_name" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$global_var_name] or insert $node_type ${pl_names[1]}: " true "$global_var_name"
                else
                        get_input "txt" "Insert $node_type ${pl_names[1]}: " false
                fi
                temp_name=${input_variable,,}
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
                        master_name=$temp_name
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
                        display_error "Incorrect parameters get_node function"
        esac
}

function get_ocp_domain() {
        msg "Set cluster domain name" task
        msg "Insert the OCP cluster domain name - it will be managed by DNS on bastion but OCP clients must correctly resolves names to get acccess to" info
        while $(check_input "domain" ${ocp_domain})
        do
                if [[ ! -z "$GI_DOMAIN" ]]
                then
                        get_input "txt" "Press <ENTER> to accept the previous choice [$GI_DOMAIN] or insert domain name: " true "$GI_DOMAIN"
                else
                        get_input "txt" "Insert domain name: " false
                fi
                ocp_domain=${input_variable}
        done
        save_variable GI_DOMAIN $ocp_domain
}

function get_ocp_version_prescript() {
        while $(check_input "list" ${ocp_major_version} ${#ocp_major_versions[@]})
        do
                get_input "list" "Select OCP major version: " "${ocp_major_versions[@]}"
                ocp_major_version=$input_variable
        done
        ocp_major_version=$(($ocp_major_version-1))
        ocp_major_release="${ocp_major_versions[${ocp_major_version}]}"
        if [[ "$1" != "major" ]]
        then
                msg "Insert minor version of OpenShift ${ocp_major_versions[${ocp_major_version}]}.x" info
                msg "The latest stable version can be identified using this URL: https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-${ocp_major_versions[${ocp_major_version}]}" info
                msg "The latest version can be identified using this URL: https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/candidate-${ocp_major_versions[${ocp_major_version}]}" info
                ocp_release_minor=${ocp_release_minor:-Z}
                while $(check_input "int" ${ocp_release_minor} 0 1000)
                do
                        get_input "int" "Insert minor version of OCP ${ocp_major_versions[${ocp_major_version}]} to install (must be existing one): " false
                        ocp_release_minor=${input_variable}
                done
                ocp_release="${ocp_major_versions[${ocp_major_version}]}.${ocp_release_minor}"
        fi
}

function get_pull_secret() {
        msg "You must provide the RedHat account pullSecret to get access to image registries" info
        local is_ok=true
        while $is_ok
        do
                get_input "txt" "Insert RedHat pull secret: " false
                if [ "${input_variable}" ]
                then
                        jq .auths <<< ${input_variable} && is_ok=false || is_ok=true
                        rhn_secret="${input_variable}"
                fi
        done
}

function get_px_options() {
        msg "Gather Portworx Essential Parameters" task
        msg "Portworx will use all disks available on nodes specified by path /dev/${storage_device}" info
        msg "Please insert your Essential Entitlement ID, it must be unlinked to be usable for deploying new Portwork Storage Server instance (https://central.portworx.com/profile)" info
        while $(check_input "uuid" ${px_id})
        do
                if [[ ! -z "$GI_PX_ID" ]]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_PX_ID] or insert Portworx Essential Entitlement ID: " true "$GI_PX_ID"
                else
                        get_input "txt" "Insert Portworx Essential Entitlement ID: " false
                fi
                px_id=${input_variable}
        done
        save_variable GI_PX_ID $px_id
}

function get_rook_settings() {
	local rook_deployment_type
	local deployment_types
	deployment_types=("Standard" "Simple" "Cloud_Pak")
	msg "Rook-Ceph configuration:" task
	msg "- Standard - production deployment assumes that rook-ceph volumes store 3 copies of data" info
	msg "- Simple - each volume will store 2 chunks of data" info
	msg "- Cloud_Pak - two sets of storage classes will be created, one without data redundancy (for Mongo, Redis, Kafka, PGSQL) and one with 2 copies (for DB2DWH)" info
	msg "You can change default behaviour and deploy rook-ceph more controlled way" info
	while $(check_input "list" ${rook_deployment_type} ${#deployment_types[@]})
        do
        	get_input "list" "Select rook-ceph storage deployment: " ${deployment_types[@]}
                rook_deployment_type=$input_variable
        done
	save_variable GI_ROOK_DEPL $rook_deployment_type
}

function get_service_assignment() {
        msg "Architecture decisions about service location on cluster nodes" task
        local -a selected_arr
        local -a node_arr
        local element
        local rook_on_list
	local worker_wo_db2_name
	local workers_for_gi_selection
	local nodes_for_selection
	local -a local_arr
        [[ $is_master_only == 'Y' ]] && available_nodes=$master_name || available_nodes=$worker_name
        if [[ $gi_install == 'Y' ]]
        then
                if [[ $db2_tainted == 'Y' ]]
                then
                        msg "You decided that DB2 will be installed on dedicated node/nodes" info
                        msg "Node/nodes should not be used as storage cluster nodes" info
                else
                        msg "Insert node/nodes name where DB2 should be installed" info
                fi
                msg "DB2 node/nodes should have enough resources (CPU, RAM) to get this role, check GI documentation" info
                msg "Available worker nodes: $available_nodes" info
                while $(check_input "nodes" $db2_nodes $available_nodes $db2_nodes_number "def")
                do
                        if [ ! -z "$GI_DB2_NODES" ]
                        then
                                get_input "txt" "Push <ENTER> to accept the previous choice [$GI_DB2_NODES] or specify $db2_nodes_number node/nodes names (comma separated, without spaces)?: " true "$GI_DB2_NODES"
                        else
                                get_input "txt" "Specify $db2_nodes_number node/nodes names (comma separated, without spaces)?: " false
                        fi
                        db2_nodes=${input_variable}
                done
                save_variable GI_DB2_NODES "$db2_nodes"
		if [[ $db2_tainted == 'Y' ]]
                then
                	IFS=',' read -r -a selected_arr <<< "$db2_nodes"
                	IFS=',' read -r -a node_arr <<< "$worker_name"
                	for element in ${selected_arr[@]};do node_arr=("${node_arr[@]/$element}");done
                	worker_wo_db2_name=`echo ${node_arr[*]}|tr ' ' ','`
        	else
                	IFS=',' read -r -a node_arr <<< "$worker_name"
               	 	worker_wo_db2_name="${worker_name[@]}"
		fi
        fi
	IFS=',' read -r -a local_arr <<< "$GI_ROOK_NODES"
	if [[ $storage_type == "R" && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
        then
                msg "You specified Rook-Ceph as a cluster storage" info
                msg "You can force to deploy it on defined nodes only" info
                msg "Only disks from specified nodes will be configured as a cluster storage" info
                while $(check_input "yn" $rook_on_list false)
                do
			if [ ${#local_arr[@]} -eq 3 ]
			then
				get_input "yn" "Would you like to install Rook-Ceph on specified nodes or press ENTER to confirm previous decision [Y]? " true 'Y'
			else
                        	get_input "yn" "Would you like to install Rook-Ceph on specified nodes?: " true
			fi
                        rook_on_list=${input_variable^^}
                done
                if [ "$rook_on_list" == 'Y' ]
                then
                        msg "Available worker nodes:  $worker_wo_db2_name" info
                        while $(check_input "nodes" $rook_nodes $worker_wo_db2_name 3 "def")
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
        if [[ $storage_type == "O" && $ocs_tainted == 'N' && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
        then
                msg "You must specify cluster nodes for ODF deployment" info
                msg "These nodes must have additional disk attached for this purpose" info
                msg "Available worker nodes: $worker_wo_db2_name" info
                while $(check_input "nodes" $ocs_nodes $worker_wo_db2_name 3 "def")
                do
                        if [ ! -z "$GI_OCS_NODES" ]
                        then
                                get_input "txt" "Push <ENTER> to accept the previous choice [$GI_OCS_NODES] or specify 3 nodes (comma separated, without spaces)?: " true "$GI_OCS_NODES"
                        else
                                get_input "txt" "Specify 3 nodes (comma separated, without spaces)?: " false
                        fi
                        ocs_nodes=${input_variable}
                done
                save_variable GI_OCS_NODES "$ocs_nodes"
        else
		[[ $storage_type == "O" ]] && save_variable GI_OCS_NODES "$worker_name" || save_variable GI_OCS_NODES ''
        fi
	IFS=',' read -r -a local_arr <<< "$GI_ICS_NODES"
        if [[ $ics_install == "Y" && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
        then
                msg "You can force to deploy CPFS on strictly defined node list" info
                while $(check_input "yn" $ics_on_list false)
                do
			if [ ${#local_arr[@]} -eq 3 ]
                        then
				get_input "yn" "Would you like to install CPFS on specified nodes or press ENTER to confirm previous decision [Y]? " true 'Y'
			else
                        	get_input "yn" "Would you like to install CPFS on specified nodes?: " true
			fi
                        ics_on_list=${input_variable^^}
                done
                if [ "$ics_on_list" == 'Y' ]
                then
                        msg "Available worker nodes: $worker_wo_db2_name" info
                        while $(check_input "nodes" $ics_nodes $worker_wo_db2_name 3 "def")
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
                save_variable GI_ICS_NODES "$ics_nodes"
	else
		save_variable GI_ICS_NODES ''
        fi
	if [ "$gi_install" == 'Y' ]
        then
		local -a available_nodes_arr
		IFS=',' read -r -a local_arr <<< "$GI_GI_NODES"
		IFS=',' read -r -a available_nodes_arr <<< "$worker_wo_db2_name"
                IFS=',' read -r -a worker_arr <<< "$worker_name"
                if [[ ( $db2_tainted == 'Y' && ${#node_arr[@]} -gt 3 ) || ( $db2_tainted == 'N' && ${#available_nodes_arr[@]} -gt 3 ) ]]
                then
                        msg "You can force to deploy GI on strictly defined node list" info
                        while $(check_input "yn" $gi_on_list false)
                        do
				if [ ${#local_arr[@]} -gt 0 ]
                        	then
					get_input "yn" "Would you like to install GI on specified nodes or press ENTER to confirm previous decision [Y]? " true 'Y'	
				else
                                	get_input "yn" "Would you like to install GI on specified nodes?: " true
				fi
                                gi_on_list=${input_variable^^}
                        done
                fi
                if [ "$gi_on_list" == 'Y' ]
                then
			local gi_nodes_needed
			if [[ $db2_tainted == 'N' ]]
			then
				gi_nodes_needed=`expr 3 - $db2_nodes_number`
			else
				gi_nodes_needed=3
			fi
                        if [ ! -z "$GI_GI_NODES" ]
                        then
                                local previous_node_ar
                                local current_selection
                                IFS=',' read -r -a previous_node_arr <<< "$GI_GI_NODES"
                                IFS=',' read -r -a db2_node_arr <<< "$db2_nodes"
                                for element in ${db2_node_arr[@]};do previous_node_arr=("${previous_node_arr[@]/$element}");done
                                current_selection=`echo ${previous_node_arr[*]}|tr ' ' ','`
                        fi
                        msg "DB2 node/nodes: $db2_nodes are already on the list included, additionally you must select minimum $gi_nodes_needed node/nodes from the list below:" info
                        msg "Available worker nodes: $worker_wo_db2_name" info
                        while $(check_input "nodes" $gi_nodes $worker_wo_db2_name $gi_nodes_needed "max")
                        do
                                if [ ! -z "$GI_GI_NODES" ]
                                then
                                        get_input "txt" "Push <ENTER> to accept the previous choice [$current_selection] or specify minimum $gi_nodes_needed node/nodes (comma separated, without spaces)?: " true "$current_selection"
                                else
                                        get_input "txt" "Specify minimum $no_nodes_2_select node/nodes (comma separated, without spaces)?: " false
                                fi
                                gi_nodes=${input_variable}
                        done
                        save_variable GI_GI_NODES "${db2_nodes},$gi_nodes"
                else
                        save_variable GI_GI_NODES ""
                fi
        fi
}

function get_set_services() {
        local iz_tz_ok
        local is_td_ok
        local ntpd_server
        local tzone
        local tida
	local ntp_clients
        msg "Some additional questions allow to configure supporting services in your environment" info
        msg "Time settings" task
        msg "It is recommended to use existing NTPD server in the local intranet but you can also decide to setup bastion as a new one" info
        while $(check_input "yn" $install_ntpd false)
        do
                get_input "yn" "Would you like setup NTP server on bastion?: " false
                install_ntpd=${input_variable^^}
        done
        if [[ $install_ntpd == 'N' ]]
        then
                timedatectl set-ntp true
                while $(check_input "ip" ${ntpd_server})
                do
                        if [ ! -z "$GI_NTP_SRV" ]
                        then
                                get_input "txt" "Push <ENTER> to accept the previous choice [$GI_NTP_SRV] or insert remote NTP server IP address: " true "$GI_NTP_SRV"
                        else
                                get_input "txt" "Insert remote NTP server IP address: " false
                        fi
                        ntpd_server=${input_variable}
                done
                save_variable GI_NTP_SRV $ntpd_server
        else
		msg "NTP server set on bastion requires information about client subnets to serve. Insert value using CIDR notation, for example 192.168.10.0/24" info
		while $(check_input "cidr" "${ntp_clients}")
                do
                        if [ ! -z "$GI_NTP_CLIENTS" ]
			then
				get_input "txt" "Insert subnet specification to define IP address space served by NTP server on bastion or press ENTER to accept previous value [$GI_NTP_CLIENTS]: " true "${GI_NTP_CLIENTS}"
			else
				get_input "txt" "Insert subnet specification to define IP address space served by NTP server on bastion: " false
			fi
			ntp_clients=${input_variable}
		done
		save_variable GI_NTP_CLIENTS $ntp_clients
                ntpd_server=$bastion_ip
                timedatectl set-ntp false
        fi
        set_bastion_ntpd_client "$ntpd_server"
        msg "Ensure that TZ and corresponding time is set correctly" task
        while $(check_input "yn" $is_tz_ok)
        do
                get_input "yn" "Your Timezone on bastion is set to `timedatectl show|grep Timezone|awk -F '=' '{ print $2 }'`, is it correct one?: " false
                is_tz_ok=${input_variable^^}
        done
        if [[ $is_tz_ok == 'N' ]]
        then
                while "tz" $(check_input ${tzone})
                do
                        get_input "txt" "Insert your Timezone in Linux format (i.e. Europe/Berlin): " false
                        tzone=${input_variable}
                done
        fi
	if [[ $install_ntpd == 'Y' ]]
        then
                save_variable GI_NTP_SRV $bastion_ip
                msg "Ensure that date and time are set correctly" task
                while $(check_input "yn" $is_td_ok false)
                do
                        get_input "yn" "Current local time is `date`, is it correct one?: " false
                        is_td_ok=${input_variable^^}
                done
                if [[ $is_td_ok == 'N' ]]
                then
                        while $(check_input "td" "${tida}")
                        do
                                get_input "txt" "Insert correct date and time in format \"2012-10-30 18:17:16\": " false
                                tida="${input_variable}"
                        done
                fi
        fi
        msg "DNS settings" task
        msg "Provide the DNS which will able to resolve intranet and internet names" info
        msg "In case of air-gapped installation you can point bastion itself but cluster will not able to resolve intranet names, in this case you must later update manually dnsmasq.conf settings" info
        while $(check_input "ip" ${dns_fw})
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
        if [[ "$one_subnet" == 'Y' ]]
        then
                save_variable GI_DHCP_RANGE_START `printf '%s\n' "${all_ips[@]}"|sort -t . -k 3,3n -k 4,4n|head -n1`
                save_variable GI_DHCP_RANGE_STOP `printf '%s\n' "${all_ips[@]}"|sort -t . -k 3,3n -k 4,4n|tail -n1`
        fi
}

function get_software_architecture() {
        msg "Some important architecture decisions about software deployment must be made now" task
        msg "3 nodes only instalation consideration decisions" info
        msg "This kind of architecture has some limitations:" info
        msg "- You cannot isolate storage on separate nodes" info
        msg "- You cannot isolate GI, EDR, CP4S and CPFS" info
        while $(check_input "yn" ${is_master_only})
        do
		if [[ ! -z "$GI_MASTER_ONLY" ]]
                then
			get_input "yn" "Is your installation the 3 nodes only (push ENTER to accept previous selection [$GI_MASTER_ONLY])? " true $GI_MASTER_ONLY
		else
                	get_input "yn" "Is your installation the 3 nodes only? " true
		fi
                is_master_only=${input_variable^^}
        done
        save_variable GI_MASTER_ONLY $is_master_only
        msg "Decide what kind of cluster storage option will be implemented:" info
        msg "- OpenShift Data Fountation - commercial rook-ceph branch from RedHat" info
        msg "- Rook-Ceph - opensource cluster storage option" info
        if [ $use_air_gap == 'N' ]
        then
        	msg "- Portworx Essentials - free version of Portworx Enterprise cluster storage option, it has limitation to 5 workers and 5 TB of storage" info
                while $(check_input "stopx" ${storage_type})
                do
			if [[ ! -z "$GI_STORAGE_TYPE" ]]
                        then
				get_input "stopx" "Select storage backend (O)DF/(R)ook/(P)ortworx or press ENTER to accept the previous choice [$GI_STORAGE_TYPE]: " true "$GI_STORAGE_TYPE"
			else
	                	get_input "stopx" "Choice the cluster storage type? (O)DF/(\e[4mR\e[0m)ook/(P)ortworx: " true
      	                	[[ ${input_variable} == '' ]] && input_variable='R'
			fi
               	        storage_type=${input_variable^^}
                done
        else
                while $(check_input "sto" ${storage_type})
                do
			if [[ ! -z "$GI_STORAGE_TYPE" ]]
                        then
                                get_input "stopx" "Select storage backend (O)DF/(R)ook or press ENTER to accept the previous choice [$GI_STORAGE_TYPE]: " true "$GI_STORAGE_TYPE"
                        else
	                	get_input "stopx" "Choice the cluster storage type? (O)DF/(\e[4mR\e[0m)ook: " true
			fi
                        [[ ${input_variable} == '' ]] && input_variable='R'
                        storage_type=${input_variable^^}
                done
        fi
        save_variable GI_STORAGE_TYPE $storage_type
	[[ $storage_type == "R" ]] && get_rook_settings # get storage redundacy
        if [[ $storage_type == "O" && $is_master_only == 'N' && false ]] # check tainting
        then
                msg "ODF tainting will require minimum 3 additional workers in your cluster to manage cluster storage" info
                while $(check_input "yn" ${ocs_tainted})
                do
			if [[ ! -z "$GI_OCS_TAINTED" ]]
			then
				get_input "yn" "Decide to taint ODF or push ENTER to accept selection [$GI_OCS_TAINTED] " true $GI_OCS_TAINTED
			else
                        	get_input "yn" "Should be ODF tainted? " true
			fi
                        ocs_tainted=${input_variable^^}
                done
                save_variable GI_OCS_TAINTED $ocs_tainted
        else
                save_variable GI_OCS_TAINTED "N"
        fi
        if [[ $gi_install == "Y" ]]
        then
                while $(check_input "list" ${gi_size_selected} ${#gi_sizes[@]})
                do
                        get_input "list" "Select Guardium Insights deployment template: " "${gi_sizes[@]}"
                        gi_size_selected=$input_variable
                done
                gi_size="${gi_sizes[$((${gi_size_selected} - 1))]}"
                save_variable GI_SIZE_GI $gi_size
		msg "You must decide how many DB2 nodes will be deployed (max 3). These nodes can be used for other services but requires more resources to cover datewarehouse load" info
                while $(check_input "int" ${db2_nodes_number} 1 3)
                do
			if [[ ! -z "$GI_DB2_NODES_NUMBER" && $GI_DB2_NODES_NUMBER -ne 0 ]]
                	then
                        	get_input "int" "Push <ENTER> to accept the previous choice [$GI_DB2_NODES_NUMBER] or insert number of DB2 nodes to deploy: " true "$GI_DB2_NODES_NUMBER"
                	else
                        	get_input "int" "How many DB2 nodes will be deployed?: "
                	fi
                        db2_nodes_number=${input_variable^^}
                done
                save_variable GI_DB2_NODES_NUMBER $db2_nodes_number
        else
                save_variable GI_DB2_NODES_NUMBER 0
        fi
        if [[ $gi_install == "Y" && $is_master_only == 'N' ]]
        then
		if [[ $storage_type != 'P' || ( $storage_type == 'P' && $db2_nodes_number -lt 3 ) ]]
		then	
                	msg "DB2 tainting will require additional workers in your cluster to manage Guardium Insights database backend" info
                	while $(check_input "yn" ${db2_tainted})
                	do
				if [[ ! -z "$GI_DB2_TAINTED" ]]
                        	then
                                	get_input "yn" "Decide to taint DB2 nodes or confirm previous decision [$GI_DB2_TAINTED] " true $GI_DB2_TAINTED
                        	else
                        		get_input "yn" "Should be DB2 tainted?: " true
                        	fi
                        	db2_tainted=${input_variable^^}
                	done
               	 	save_variable GI_DB2_TAINTED $db2_tainted
		else
			[[ $storage_type == 'P' && $db2_nodes_number -eq 3 ]] && msg "DB2 cannot be tainted because Portworx Essential has limitation of 5 workers only" info
			save_variable GI_DB2_TAINTED 'N'
		fi
        else
                save_variable GI_DB2_TAINTED "N"
        fi
}

function get_software_selection() {
	ics_install='N'
        msg "gi-runner offers installation of Guardium Insights (GI)" info
        while $(check_input "yn" ${gi_install})
        do
		if [[ ! -z "$GI_INSTALL_GI" ]]
                then
			get_input "yn" "Decide if Guardium Insights is to be installed or press ENTER to confirm previous selection [$GI_INSTALL_GI] " false $GI_INSTALL_GI
		else
                	get_input "yn" "Would you like to install Guardium Insights? " false
		fi
                gi_install=${input_variable^^}
        done
        save_variable GI_INSTALL_GI $gi_install
        if [[ $gi_install == 'N' ]]
        then
                msg "gi-runner offers installation of Cloud Pak for Security (CP4s) - latest version from channel $cp4s_channel" info
                while $(check_input "yn" ${cp4s_install})
                do
			if [[ ! -z "$GI_CP4S" ]]
                	then
				get_input "yn" "Decide if CP4S is to be installed or press ENTER to confirm previous selection [$GI_CP4S] " true $GI_CP4S
			else
                        	get_input "yn" "Would you like to install CP4S? " false
			fi
                        cp4s_install=${input_variable^^}
                done
        else
                cp4s_install='N'
        fi
        save_variable GI_CP4S $cp4s_install
        if [[ $gi_install == 'N' && $cp4s_install == 'N' ]]
        then
                msg "gi-runner offers installation of IBM Security Qradar EDR - latest version" info
                while $(check_input "yn" ${edr_install})
                do
			if [[ ! -z "$GI_EDR" ]]
                        then
				get_input "yn" "Decide if EDR is to be installed or press ENTER to confirm previous selection [$GI_EDR] " true $GI_EDR
			else
                        	get_input "yn" "Would you like to install EDR? " false
			fi
                        edr_install=${input_variable^^}
                done
        else
                edr_install='N'
        fi
        save_variable GI_EDR $edr_install
        [[ $gi_install == 'Y' ]] && select_gi_version
        [ $edr_install == 'N' -a $cp4s_install == 'N' -a $gi_install == 'N' ] && select_ics_version
        save_variable GI_ICS $ics_install
        select_ocp_version
        while $(check_input "yn" ${install_ldap})
        do
		if [[ ! -z "$GI_INSTALL_LDAP" ]]
                then
			get_input "yn" "Decide to deploy OpenLDAP or press ENTER to confirm previous selection [$GI_INSTALL_LDAP] " true $GI_INSTALL_LDAP
		else
                	get_input "yn" "Would you like to install OpenLDAP? " false
		fi
                install_ldap=${input_variable^^}
        done
        save_variable GI_INSTALL_LDAP $install_ldap
}

function get_worker_nodes() {
        local worker_number=3
        local inserted_worker_number
	if [[ ! -z "$GI_WORKER_NAME" ]]
	then
		local -a workers_list
		IFS="," read -r -a workers_list <<< $GI_WORKER_NAME
	fi
        if [[ $is_master_only == 'N' ]]
        then
                msg "Collecting workers data" task
                [[ $storage_type == 'P' ]] && max_workers_number=5 || max_workers_number=50
                if [[ $storage_type == 'O' && $ocs_tainted == 'Y' ]]
                then
                        msg "Collecting ODF dedicated nodes data because tainting has been chosen" task
                        get_nodes_info 3 "ocs"
                fi
                if [[ "$db2_tainted" == 'Y' ]]
                then
			worker_number=$(($worker_number + $db2_nodes_number))
                fi
                msg "Your cluster architecture decisions require to have minimum $worker_number additional workers" info
                [[ $storage_type == 'P' ]] && msg "Because Portworx Essential will be installed you can specify maximum 5 workers, limitation of this free Portworx release" info
		[[ $storage_type == 'R' ]] && msg "If you plan deploy rook on dedicated nodes, you must deploy minimum $(($worker_number + 3)) nodes" info
		[[ $gi_install == 'Y' && $storage_type != 'P' ]] && msg "If you plan deploy CPFS on dedicated nodes, you must deploy minimum $(($worker_number + 3)) nodes" info
                while $(check_input "int" $inserted_worker_number $worker_number $max_workers_number)
                do
			if [[ ! -z "$GI_WORKER_NAME" ]]
        		then
                		local -a workers_list
                		IFS="," read -r -a workers_list <<< $GI_WORKER_NAME
				get_input "int" "How many workers would you like to add to cluster? (press ENTER to confirm previous decision [${#workers_list[@]}]): " false ${#workers_list[@]}
				
			else
 	                        get_input "int" "How many workers would you like to add to cluster?: " false
			fi
        	        inserted_worker_number=${input_variable}
                done
                msg "Collecting workers nodes data (IP and MAC addresses, node names), values inserted as comma separated list without spaces" task
                get_nodes_info $inserted_worker_number "wrk"
        fi
}

function msg() {
        case "$2" in
                "continue")
                        printf "$1"
                        ;;
                "newline")
                        printf "$1\n"
                        ;;
                "monit")
                        printf "\e[1m>>> $1"
                        ;;
                "task")
                        printf "\e[34m\e[2mTASK:\e[22m $1\n\e[0m"
                        ;;
                "info")
                        printf "\e[2mINFO:\e[22m \e[97m$1\n\e[0m"
                        ;;
		"title")
			printf "\e[1m$1\n\e[0m"
			printf "\e[32m--------------------------------------------------------------------------------\n\e[0m"
                        ;;
                "error")
                        printf "\e[31m--------------------------------------------------------------------------------\n"
                        if [ "$1" ]
                        then
                                printf "Error: $1\n"
                        else
                                printf "Error in subfunction\n"
                        fi
                        printf -- "--------------------------------------------------------------------------------\n"
                        printf "\e[0m"
                        ;;
                *)
                        display_error "msg with incorrect parameter - $2"
                        ;;
        esac
}

function prepare_bastion() {
	msg "Prepare bastion" task
	check_linux_distribution_and_release
	msg "This machine should be on this same patch leve as target bastion to avoid libraries incompatibility between software packages" info
	while $(check_input "yn" ${update_bastion})
        do
		get_input "yn" "Should be target bastion updated (Y) or only necessary software packages added (N) " false
                update_bastion=${input_variable^^}
        done
	msg "Gathering OS release and kernel version" task
	echo `cat /etc/system-release|sed -e "s/ /_/g"` > $GI_TEMP/airgap/os_release.txt
	echo `uname -r` > $GI_TEMP/airgap/kernel.txt
	if [[ $update_bastion == 'Y' ]]
	then
		msg "Get the latest system patches ..." task
		mkdir -p $GI_TEMP/airgap/os-updates
		cd $GI_TEMP/airgap
		dnf update -qy --downloadonly --downloaddir os-updates
		test $(check_exit_code $?) || (msg "Cannot download update packages" info; exit 1)
		msg "Update system ..." task
		cd os-updates
		dnf -qy localinstall * --allowerasing || msg "System is up to date" info
		test $(check_exit_code $?) || (msg "Cannot update system" info; exit 1)
	fi
	cd $GI_TEMP/airgap
	mkdir -p $GI_TEMP/airgap/os-packages
	msg "Downloading additional OS packages ..." task
	for package in ${linux_soft[@]}
	do
        	dnf download -qy --downloaddir os-packages $package --resolve
        	test $(check_exit_code $?) || (msg "Cannot download $package package" info; exit 1)
        	msg "Downloaded: $package" info
	done
	msg "Installing missing packages ..." task
	dnf -qy install python3 podman wget python3-pip
	test $(check_exit_code $?) || (msg "Cannot install support tools" info; exit 1)
	cd $GI_TEMP/airgap
        mkdir -p $GI_TEMP/airgap/ansible
	msg "Downloading python packages for Ansible extensions ..." task
	for package in ${python_soft[@]}
	do
        	python3 -m pip download --only-binary=:all: $package -d ansible > /dev/null 2>&1
	        test $(check_exit_code $?) || (msg "Cannot download Python module - $package" info; exit 1)
        	msg "Downloaded: $package" info
	done
	cd $GI_TEMP/airgap
        mkdir -p $GI_TEMP/airgap/galaxy
	msg "Downloading Ansible Galaxy extensions ..." task
	for galaxy_package in ${galaxy_soft[@]}
	do
        	wget -P galaxy https://galaxy.ansible.com/download/${galaxy_package}.tar.gz > /dev/null 2>&1
	        test $(check_exit_code $?) || (msg "Cannot download Ansible galaxy package ${galaxy_package}" info; exit 1)
        	msg "Downloaded: $galaxy_package" info
	done
	mkdir -p $GI_TEMP/downloads
	msg "Preparing archives ..." task
	tar cf $GI_TEMP/downloads/os-`cat /etc/system-release|sed -e "s/ /_/g"`-`date +%Y-%m-%d`.tar os-updates os-packages ansible galaxy os_release.txt kernel.txt
	wget -P $GI_TEMP/downloads https://github.com/zbychfish/gi-runner/archive/refs/heads/main.zip > /dev/null 2>&1
	test $(check_exit_code $?) || (msg "Cannot download gi-runner archive from github" info; exit 1)
	mv $GI_TEMP/downloads/main.zip $GI_TEMP/downloads/gi-runner.zip
	dnf download -qy --downloaddir $GI_TEMP/downloads unzip --resolve
}

function prepare_ocp() {
	msg "You must provide the exact version of OpenShift for its images mirror process" info
	msg "It is suggested to install a release from stable repository" info
	get_ocp_version_prescript
	get_pull_secret
	msg "Installing podman, httpd-tools jq openssl policycoreutils-python-utils wget ..." task
	dnf -qy install podman httpd-tools openssl jq policycoreutils-python-utils wget
	test $(check_exit_code $?) || (msg "Cannot install httpd-tools" info; exit 1)
	msg "Download a mirror image registry ..." task
	podman pull docker.io/library/registry:${registry_version} &>/dev/null
	test $(check_exit_code $?) || (msg "Cannot download image registry" true; exit 1)
	msg "Save image registry image ..." task
	podman save -o $GI_TEMP/airgap/oc-registry.tar docker.io/library/registry:${registry_version} &>/dev/null
	podman rmi --all --force &>/dev/null
	msg "Download OCP, support tools and CoreOS images ..." task
	cd $GI_TEMP/airgap
	declare -a ocp_files=("https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-client-linux.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/openshift-install-linux.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-initramfs.x86_64.img" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-kernel-x86_64" "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_release}/latest/rhcos-live-rootfs.x86_64.img" "https://github.com/poseidon/matchbox/releases/download/v${matchbox_version}/matchbox-v${matchbox_version}-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/oc-mirror.tar.gz")
	for file in ${ocp_files[@]}
	do
        	download_file $file
	done
        msg "Installing OCP tools ..." task
        tar xf $GI_TEMP/airgap/openshift-client-linux.tar.gz -C /usr/local/bin &>/dev/null
        tar xf $GI_TEMP/airgap/oc-mirror.tar.gz -C /usr/local/bin &>/dev/null
        chmod +x /usr/local/bin/oc-mirror
	mkdir -p /run/user/0/containers #if podman was not initiated yet
	echo $rhn_secret | jq . > ${XDG_RUNTIME_DIR}/containers/auth.json
	setup_local_registry
	LOCAL_REGISTRY="$(hostname --long):${temp_registry_port}"
	msg "Login to local registry ${LOCAL_REGISTRY}" info
	podman login -u $temp_registry_user -p $temp_registry_password ${LOCAL_REGISTRY}
	msg "Prepare imageset file" info
	cp $GI_HOME/funcs/scripts/ocp-images.yaml $GI_TEMP
	sed -i "s#imageURL:#imageURL: ${LOCAL_REGISTRY}/mirror/metadata#" $GI_TEMP/ocp-images.yaml
	sed -i "s/.ocp_version./${ocp_major_release}/" $GI_TEMP/ocp-images.yaml
	sed -i "s#.gitemp.#${GI_TEMP}#" $GI_TEMP/ocp-images.yaml
	sed -i "s/minVersion/minVersion: ${ocp_release}/" $GI_TEMP/ocp-images.yaml
	sed -i "s/maxVersion/maxVersion: ${ocp_release}/" $GI_TEMP/ocp-images.yaml
	mkdir -p $GI_TEMP/images
	TMPDIR=$GI_TEMP/images oc mirror --config $GI_TEMP/ocp-images.yaml docker://${LOCAL_REGISTRY} --dest-skip-tls
	test $(check_exit_code $?) && msg "OCP images mirrored" info || msg "Cannot mirror OCP images" info
	msg "Mirroring finished succesfully" info
	podman stop bastion-registry &>/dev/null
	mkdir -p $GI_TEMP/downloads/OCP-${ocp_release}
	mv $GI_TEMP/airgap/oc-registry.tar $GI_TEMP/downloads/OCP-${ocp_release}
	cd /opt/registry
	msg "Archiving OCP images ..." info
	tar cf $GI_TEMP/downloads/OCP-${ocp_release}/ocp-images-data.tar data
	cd $GI_TEMP/airgap/oc-mirror-workspace/results-*
	msg "Archiving OCP operator index and source policy ..." info
	tar cf $GI_TEMP/downloads/OCP-${ocp_release}/ocp-images-yamls.tar catalogSource-redhat-operator-index.yaml imageContentSourcePolicy.yaml
	cd $GI_TEMP/airgap
	msg "Archiving OCP tools ..." info
	tar cf $GI_TEMP/downloads/OCP-${ocp_release}/ocp-tools.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img "matchbox-v${matchbox_version}-linux-amd64.tar.gz" oc-mirror.tar.gz oc-registry.tar
	msg "Cleaning registry ..." info
	podman rm bastion-registry &>/dev/null
	podman rmi --all &>/dev/null
	rm -rf /opt/registry/data
}

function prepare_rook() {
	msg "Gathering Rook-Ceph version details ..." task
	ceph_path="deploy/examples"
	images="docker.io/rook/ceph:${rook_version}"
	cd $GI_TEMP
	echo "ROOK_CEPH_OPER,docker.io/rook/ceph:v${rook_operator_version}" > $GI_TEMP/rook_images
	dnf -qy install git
	check_exit_code $? "Cannot install required OS packages"
	git clone https://github.com/rook/rook.git
	cd rook
	git checkout v${rook_operator_version}
	image=`grep -e "image:.*ceph\/ceph:.*" ${ceph_path}/cluster.yaml|awk '{print $NF}'`
	images+=" "$image
	echo "ROOK_CEPH_IMAGE,$image" >> $GI_TEMP/rook_images
	declare -a labels=("ROOK_CSI_CEPH_IMAGE" "ROOK_CSI_REGISTRAR_IMAGE" "ROOK_CSI_RESIZER_IMAGE" "ROOK_CSI_PROVISIONER_IMAGE" "ROOK_CSI_SNAPSHOTTER_IMAGE" "ROOK_CSI_ATTACHER_IMAGE" "ROOK_CSIADDONS_IMAGE")
	for label in "${labels[@]}"
	do
        	image=`cat ${ceph_path}/operator-openshift.yaml|grep $label|awk -F ":" '{print $(NF-1)":"$NF}'|tr -d '"'|tr -d " "`
        	echo "$label,$image" >> $GI_TEMP/rook_images
        	images+=" "$image
	done

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
	local msg_red
	local msg_nored
	msg_nored="You must provide data redundancy on storage level"
	msg_red="You must provide data redundancy on application level"
        case $1 in
                "db2-data")
                        size_min=200
                        m_desc="DB2 DATA pvc - stores activity events, installation proces will create 1 PVC per partition on each DB2 node, each instance contains different data. $msg_nored"
                        m_ask="DB2 DATA pvc, minium size $size_min GB"
                        global_var="GI_DATA_STORAGE_SIZE"
                        global_var_val="$GI_DATA_STORAGE_SIZE"
                        ;;
                "db2-meta")
                        size_min=30
                        m_desc="DB2 METADATA pvc - stores DB2 shared, temporary, tool files, installation proces will create 1 PVC. $msg_nored"
                        m_ask="DB2 METADATA pvc, minimum size $size_min GB"
                        global_var="GI_METADATA_STORAGE_SIZE"
                        global_var_val="$GI_METADATA_STORAGE_SIZE"
                        ;;
                "db2-logs")
                        size_min=50
                        m_desc="DB2 ARCHIVELOG pvc - stores DB2 archive logs, installation proces will create 1 PVC. $msg_nored"
                        m_ask="DB2 ARCHIVELOG pvc, minium size $size_min GB"
                        global_var="GI_ARCHIVELOGS_STORAGE_SIZE"
                        global_var_val="$GI_ARCHIVELOGS_STORAGE_SIZE"
                        ;;
                "db2-temp")
                        size_min=50
                        m_desc="DB2 TEMPTS pvc - temporary objects space in DB2, installation process will create 1 PVC/PVC per DB2 node. $msg_nored"
                        m_ask="DB2 TEMPTS pvc, minium size $size_min GB"
                        global_var="GI_TEMPTS_STORAGE_SIZE"
                        global_var_val="$GI_TEMPTS_STORAGE_SIZE"
                        ;;
                "mongo-data")
                        size_min=50
                        m_desc="MONGODB DATA pvc - stores MongoDB data related to GI metadata and reports, installation process will create 3 PVC's. $msg_red"
                        m_ask="MONGODB DATA pvc, minium size $size_min GB"
                        global_var="GI_MONGO_DATA_STORAGE_SIZE"
                        global_var_val="$GI_MONGO_DATA_STORAGE_SIZE"
                        ;;
                "mongo-logs")
                        size_min=10
                        m_desc="MONGODB LOG pvc - stores MongoDB logs, installation process will create 3 PVC's. $msg_red"
                        m_ask="MONGODB LOG pvc, minium size $size_min GB"
                        global_var="GI_MONGO_METADATA_STORAGE_SIZE"
                        global_var_val="$GI_MONGO_METADATA_STORAGE_SIZE"
                        ;;
                "kafka")
                        size_min=50
                        m_desc="KAFKA pvc - stores ML and Streaming data for last 7 days, installation process will create 3 PVC's. $msg_red"
                        m_ask="KAFKA pvc, minium size $size_min GB"
                        global_var="GI_KAFKA_STORAGE_SIZE"
                        global_var_val="$GI_KAFKA_STORAGE_SIZE"
                        ;;
		"zookeeper")
                        size_min=5
                        m_desc="ZOOKEEPER pvc - stores Kafka configuration and health data, installation process will create 3 PVC's. $msg_red"
                        m_ask="ZOOKEEPER pvc, minium size $size_min GB"
                        global_var="GI_ZOOKEEPER_STORAGE_SIZE"
                        global_var_val="$GI_ZOOKEEPER_STORAGE_SIZE"
                        ;;
                "redis")
                        size_min=5
                        m_desc="REDIS pvc - stores Redis configuration and cached session data, installation process will create 3 PVC's. $msg_red"
                        m_ask="REDIS pvc, minium size $size_min GB"
                        global_var="GI_REDIS_STORAGE_SIZE"
                        global_var_val="$GI_REDIS_STORAGE_SIZE"
                        ;;
                "pgsql")
                        size_min=5
                        m_desc="POSTGRES pvc - stores anomalies and analytics data, installation process will create 3 PVC's. $msg_red"
                        m_ask="POSTGRES pvc, minium size $size_min GB"
                        global_var="GI_POSTGRES_STORAGE_SIZE"
                        global_var_val="$GI_POSTGRES_STORAGE_SIZE"
                        ;;
		"noobaa-core")
                        size_min=20
                        m_desc="NOOBAA CORE pvc - object store for datamarts based on noobaa, installation process will create 1 PVC. $msg_nored"
                        m_ask="NOOOBAA CORE pvc, minium size $size_min GB"
                        global_var="GI_NOOBAA_CORE_SIZE"
                        global_var_val="$GI_NOOBAA_CORE_SIZE"
                        ;;
		"noobaa-backing")
                        size_min=50
			m_desc="NOOBAA BACKING STORE pvc - noobaa database (PGSQL) backend, installation process will create 2 PVC's. $msg_nored"
                        m_ask="NOOOBAA BACKING STORE pvc, minium size $size_min GB"
                        global_var="GI_NOOBAA_BACKING_SIZE"
                        global_var_val="$GI_NOOBAA_BACKING_SIZE"
                        ;;
                "*")
                        display_error "Wrong PVC type name"
                        ;;
        esac
        while $(check_input "int" "${curr_value}" $size_min $size_max)
        do
                msg "$m_desc" info
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

function save_variable() {
        echo "export $1=$2" >> $variables_file
}

function select_gi_version() {
        while $(check_input "list" ${gi_version_selected} ${#gi_versions[@]})
        do
                get_input "list" "Select GI version: " "${gi_versions[@]}"
                gi_version_selected="$input_variable"
        done
	msg "Guardium Insights installation choice assumes installation of bundled version of Cloud Pak Foundational Services (CPFS, former ICS)" info
        gi_version_selected=$(($gi_version_selected-1))
        save_variable GI_VERSION $gi_version_selected
        ics_install='Y'
        display_default_ics
}

function select_ics_version() {
	unset ics_install
        ics_version_selected=""
	if ([ -z "$nd_ics_install" ] || [ "$nd_ics_install" == 'N' ])
	then
        	while $(check_input "yn" ${ics_install})
        	do
			if [[ ! -z "$GI_ICS" ]]
                	then
				get_input "yn" "Decide to deploy CPFS or press ENTER to confirm previous selection [$GI_ICS] " true $GI_ICS
			else
	                	get_input "yn" "Would you like to install Cloud Pak Foundational Services (CPFS)? " false
			fi
                	ics_install=${input_variable^^}
        	done
	else
		ics_install='Y'
	fi
        if [[ $ics_install == 'Y' ]]
        then
                ics_version_selected=${ics_version_selected:-0}
                while $(check_input "list" ${ics_version_selected} ${#ics_versions[@]})
                do
                        get_input "list" "Select ICS version: " "${ics_versions[@]}"
                        ics_version_selected="$input_variable"
                done
                ics_version_selected=$(($ics_version_selected-1))
                save_variable GI_ICS_VERSION $ics_version_selected
        fi
}

function select_ocp_version() {
	msg "You will select the OpenShift release to deploy" info
        local i
        if [[ $gi_install == 'Y' ]]
        then
                IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_gi[$gi_version_selected]}
        elif [[ $cp4s_install == 'Y' ]]
        then
                IFS=':' read -r -a ocp_versions <<< $ocp_supported_by_cp4s
        elif [[ $ics_install == 'Y' ]]
        then
                IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_ics[$ics_version_selected]}
	elif [[ $edr_install == 'Y' ]]
        then
                IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_edr}
        fi
        local new_major_versions=()
        local i=1
        for ocp_version in "${ocp_versions[@]}"
        do
                new_major_versions+=("${ocp_major_versions[$ocp_version]}")
                i=$((i+1))
        done
        ocp_major_version=${ocp_major_version:-0}
        while $(check_input "list" ${ocp_major_version} ${#ocp_versions[@]})
        do
                get_input "list" "Select OCP major version: " "${new_major_versions[@]}"
                ocp_major_version="$input_variable"
        done
        for i in "${!ocp_major_versions[@]}"; do
                [[ "${ocp_major_versions[$i]}" == "${new_major_versions[$(($ocp_major_version-1))]}" ]] && break
        done
        ocp_major_version=$i
        if [[ $use_air_gap == 'N' ]]
        then
                ocp_release_decision=${ocp_release_decision:-Z}
                while $(check_input "es" ${ocp_release_decision})
                do
			get_input "es" "Would you like to deploy exactly specified version OCP to install or use the latest stable? (E)xact/(\e[4mS\e[0m)table: " true
                        ocp_release_decision=${input_variable^^}
                done
        else
                ocp_release_decision='E'
        fi
        if [[ $ocp_release_decision == 'E' ]]
        then
                msg "Insert minor version of OpenShift ${ocp_major_versions[${ocp_major_version}]}.x" info
                msg "It must be existing version - you can check list of available version using this URL: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_versions[${ocp_major_version}]}/latest/" info
		[[ ! -z "$GI_OCP_RELEASE" ]] && msg "Previously selected version $GI_OCP_RELEASE" info
                ocp_release_minor=${ocp_release_minor:-Z}
                while $(check_input "int" ${ocp_release_minor} 0 1000)
                do
                        get_input "txt" "Insert minor version of OCP ${ocp_major_versions[${ocp_major_version}]} to install (must be existing one): " false
                        ocp_release_minor=${input_variable}
                done
                ocp_release="${ocp_major_versions[${ocp_major_version}]}.${ocp_release_minor}"
        else
                ocp_release="${ocp_major_versions[${ocp_major_version}]}.latest"
        fi
        save_variable GI_OCP_RELEASE $ocp_release
}

function set_bastion_ntpd_client() {
        msg "Set NTPD configuration" task
        sed -i "s/^pool .*/pool $1 iburst/g" /etc/chrony.conf
        systemctl enable chronyd
        systemctl restart chronyd
}

function setup_local_registry() {
        msg "Setup mirror image registry ..." task
        podman stop bastion-registry -i
        podman container prune <<< 'Y' &>/dev/null
        podman pull docker.io/library/registry:${registry_version} &>/dev/null
        test $(check_exit_code $?) || (msg "Cannot download image registry" true; exit 1)
        mkdir -p /opt/registry/{auth,certs,data}
        openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/bastion.repo.pem -x509 -days 365 -out /opt/registry/certs/bastion.repo.crt -subj "/C=PL/ST=Miedzyrzecz/L=/O=Test /OU=Test/CN=`hostname --long`" -addext "subjectAltName = DNS:`hostname --long`" &>/dev/null
        test $(check_exit_code $?) || (msg "Cannot create certificate for temporary image registry" info; exit 1)
        cp /opt/registry/certs/bastion.repo.crt /etc/pki/ca-trust/source/anchors/
        update-ca-trust extract &>/dev/null
        htpasswd -bBc /opt/registry/auth/htpasswd $temp_registry_user $temp_registry_password &>/dev/null
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --zone=public --add-port=${temp_registry_port}/tcp --permanent &>/dev/null
        firewall-cmd --zone=public --add-service=http --permanent &>/dev/null
        firewall-cmd --reload &>/dev/null
        semanage permissive -a NetworkManager_t &>/dev/null
        msg "Starting image registry ..." task
        podman run -d --name bastion-registry -p ${temp_registry_port}:${temp_registry_port} -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:${registry_version} &>/dev/null
        test $(check_exit_code $?) || (msg "Cannot start temporary image registry" info; exit 1)
}

# Switch off the dnf sync for offline installation
function switch_dnf_sync_off() {
        if [[ `grep "metadata_timer_sync=" /etc/dnf/dnf.conf|wc -l` -eq 0 ]]
        then
                echo "metadata_timer_sync=0" >> /etc/dnf/dnf.conf
        else
                sed -i 's/.*metadata_timer_sync=.*/metadata_timer_sync=0/' /etc/dnf/dnf.conf
        fi
}

function software_installation_on_online() {
	local update_system
	local comm_out
        msg "Update and installation of software packages" task
	msg "gi-runner can update OS packages before required packages will be installed. dnf update command will be executed" info
	while $(check_input "yn" ${update_system})
        do
        	get_input "yn" "Would you like to update operating system before software package installation? " false
                update_system=${input_variable^^}
        done
	[[ $update_system == 'Y' ]] && { msg "Updating operating system ..." info; dnf -qy update; }
        msg "Installing OS packages" task
        for package in "${linux_soft[@]}"
        do
		dnf list installed ${package}.x86_64 ${package}.noarch 1> /dev/null 2> /dev/null
		if [[ $? -eq 1 ]]
		then
                	msg "- installing $package ..." info
                	dnf -qy install $package &>/dev/null
                	[[ $? -ne 0 ]] && display_error "Cannot install $package"
		fi
        done
        msg "Installing Python packages" task
        for package in "${python_soft[@]}"
        do
		pip show $package 1> /dev/null 2> /dev/null
		if [[ $? -eq 1 ]]
                then
                	msg "- installing $package ..." info
                	[[ $use_proxy == 'D' ]] && { pip3 install "$package" &> /dev/null; } || { pip3 install "$package" --proxy http://$proxy_ip:$proxy_port &> /dev/null; }
                	[[ $? -ne 0 ]] && display_error "Cannot install python package $package"
		fi
        done
        msg "Configuring Ansible" task
        mkdir -p /etc/ansible
        [[ $use_proxy == 'P' ]] && echo -e "[bastion]\n127.0.0.1 \"http_proxy=http://$proxy_ip:$proxy_port\" https_proxy=\"http://$proxy_ip:$proxy_port\" ansible_connection=local" > /etc/ansible/hosts || echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
        msg "Installing Ansible galaxy packages" task
        for package in "${galaxy_soft[@]}"
        do
                msg "- installing $package ..." info
                wget https://galaxy.ansible.com/download/${package}.tar.gz &> /dev/null
                [[ $? -ne 0 ]] && display_error "Cannot download Ansible Galaxy package $package"
                ansible-galaxy collection install ${package}.tar.gz &> /dev/null
                [[ $? -ne 0 ]] && display_error "Cannot install Ansible Galaxy package $package"
                rm -f ${package}.tar.gz
        done
        #mkdir -p ${GI_TEMP}/os
        #echo "pullSecret: '$rhn_secret'" > ${GI_TEMP}/os/pull_secret.tmp
}

function unset_proxy_settings() {
        msg "Configuring proxy settings" task
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
                "cp4s")
                        label="CP4S"
                        cert_info="$label certificate must have ASN (Alternate Subject Name) set to \"*.apps.${ocp_domain}\""
                        pre_value_ca="$GI_CP4S_CA"
                        pre_value_app="$GI_CP4S_CERT"
                        pre_value_key="$GI_CP4S_KEY"
                        ;;
		"edr")
                        label="EDR"
                        cert_info="$label certificate must have ASN (Alternate Subject Name) set to \"edr.apps.${ocp_domain}\""
                        pre_value_ca="$GI_EDR_CA"
                        pre_value_app="$GI_EDR_CERT"
                        pre_value_key="$GI_EDR_KEY"
                        ;;
                "*")
                        display_error "Unknown cert information"
                        ;;
        esac
	while $(check_input "cert" "${ca_cert}" "ca")
        do
                if [ ! -z "$pre_value_ca" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$pre_value_ca] or insert the full path to root CA of $label certificate: " true "$pre_value_ca"
                else
                        get_input "txt" "Insert the full path to root CA of $label certificate: " false
                fi
                ca_cert="${input_variable}"
        done
        msg "$cert_info" info
        while $(check_input "cert" "${app_cert}" "app" "$ca_cert")
        do
                if [ ! -z "$pre_value_app" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$pre_value_app] or insert the full path to $label certificate: " true "$pre_value_app"
                else
                        get_input "txt" "Insert the full path to $label certificate: " false
                fi
                app_cert="${input_variable}"
        done
        while $(check_input "cert" "${app_key}" "key" "$app_cert")
        do
                if [ ! -z "$pre_value_key" ]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$pre_value_key] or insert the full path to $label private key: " true "$pre_value_key"
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
                "cp4s")
                        save_variable GI_CP4S_CA "$ca_cert"
                        save_variable GI_CP4S_CERT "$app_cert"
                        save_variable GI_CP4S_KEY "$app_key"
                        ;;
		"edr")
                        save_variable GI_EDR_CA "$ca_cert"
                        save_variable GI_EDR_CERT "$app_cert"
                        save_variable GI_EDR_KEY "$app_key"
                        ;;
                "*")
                        display_error "Unknown cert information"
                        ;;
        esac
}

