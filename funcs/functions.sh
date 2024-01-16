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
                                ( ! $(check_input "ip" `echo "$2"|awk -F'/' '{print $1}'`) && ! $(check_input "int" `echo "$2"|awk -F'/' '{print $2}'` 8 22) ) && echo false || echo true
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
                "cs")
                        [[ $2 == 'C' || $2 == 'S' ]] && echo false || echo true
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

function display_default_ics() {
        local gi_version
        local i=0
        for gi_version in "${gi_versions[@]}"
        do
                msg "ICS - ${ics_versions[${bundled_in_gi_ics_versions[$i]}]} for GI $gi_version" info
                i=$((i+1))
        done
        save_variable GI_ICS_VERSION "${ics_versions[${bundled_in_gi_ics_versions[$i]}]}"
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

function get_input() {
        unset input_variable
        msg "$2" monit
        case $1 in
                "cs")
                        read input_variable
                        $3 && input_variable=${input_variable:-C} || input_variable=${input_variable:-S}
                        ;;
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

function get_network_installation_type() {
	msg "You can deploy OCP with (direct or proxy) or without (named as air-gapped, offline, disconnected) access to the internet" info
        while $(check_input "yn" ${use_air_gap})
        do
                get_input "yn" "Is your environment air-gapped? - " true
                use_air_gap=${input_variable^^}
        done
        if [ $use_air_gap == 'Y' ]
        then
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

function get_software_architecture() {
        msg "Some important architecture decisions about software deployment must be made now" task
        msg "3 nodes only instalation consideration decisions" info
        msg "This kind of architecture has some limitations:" info
        msg "- You cannot isolate storage on separate nodes" info
        msg "- You cannot isolate GI, EDR, CP4S and CPFS" info
        while $(check_input "yn" ${is_master_only})
        do
                get_input "yn" "Is your installation the 3 nodes only? " true
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
				get_input "stopx" "Push <ENTER> to accept the previous choice [$GI_STORAGE_TYPE] or select (O)DF/(R)ook/(P)ortworx: " true "$GI_STORAGE_TYPE"
			else
	                	get_input "stopx" "Choice the cluster storage type? (O)DF/(\e[4mR\e[0m)ook/(P)ortworx: " true
			fi
      	                [[ ${input_variable} == '' ]] && input_variable='R'
               	        storage_type=${input_variable^^}
                done
        else
                while $(check_input "sto" ${storage_type})
                do
			if [[ ! -z "$GI_STORAGE_TYPE" ]]
                        then
                                get_input "sto" "Push <ENTER> to accept the previous choice [$GI_STORAGE_TYPE] or select (O)DF/(R)ook: " true "$GI_STORAGE_TYPE"
                        else
	                	get_input "sto" "Choice the cluster storage type? (O)DF/(\e[4mR\e[0m)ook: " true
			fi
                        [[ ${input_variable} == '' ]] && input_variable='R'
                        storage_type=${input_variable^^}
                done
        fi
        save_variable GI_STORAGE_TYPE $storage_type
        if [[ $storage_type == "O" && $is_master_only == 'N' && false ]] # check tainting
        then
                msg "ODF tainting will require minimum 3 additional workers in your cluster to manage cluster storage" info
                while $(check_input "yn" ${ocs_tainted})
                do
			if [[ ! -z "$GI_OCS_TAINTED" ]]
			then
				get_input "yn" "Confirm previous selection [$GI_OCS_TAINTED] or select (N)o/(Y)es: " true $GI_OCS_TAINTED
			else
                        	get_input "yn" "Should be ODF tainted?: " true
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
		msg "You must decide how many DB2 nodes will be doployed (max 3). These nodes can be used for other services but requires more resources to cover datewarehouse load" info
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
                msg "DB2 tainting will require additional workers in your cluster to manage Guardium Insights database backend" info
                while $(check_input "yn" ${db2_tainted})
                do
			if [[ ! -z "$GI_DB2_TAINTED" ]]
                        then
                                get_input "yn" "Confirm previous selection [$GI_DB2_TAINTED] or select (N)o/(Y)es: " true $GI_DB2_TAINTED
                        else
                        	get_input "yn" "Should be DB2 tainted?: " true
                        fi
                        db2_tainted=${input_variable^^}
                done
                save_variable GI_DB2_TAINTED $db2_tainted
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
			get_input "yn" "Use ENTER to confirm previous selection [$GI_INSTALL_GI] or decide if Guardium Insights is to be installed " false $GI_INSTALL_GI
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
				get_input "yn" "Use ENTER to confirm previous selection [$GI_CP4S] or decide if CP4S is to be installed " true $GI_CP4S
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
				get_input "yn" "Use ENTER to confirm previous selection [$GI_EDR] or decide if EDR is to be installed " true $GI_EDR
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
        [ $edr_install == 'N' -a $cp4s_install == 'N' -a $gi_install == 'N' ] && select_ics_version || printf "$edr_install $cp4s_install $gi_install"
        save_variable GI_ICS $ics_install
        select_ocp_version
        while $(check_input "yn" ${install_ldap})
        do
		if [[ ! -z "$GI_INSTALL_LDAP" ]]
                then
			get_input "yn" "Use ENTER to confirm previous selection [$GI_INSTALL_LDAP] or decide to deploy OpenLDAP " true $GI_INSTALL_LDAP
		else
                	get_input "yn" "Would you like to install OpenLDAP? " false
		fi
                install_ldap=${input_variable^^}
        done
        save_variable GI_INSTALL_LDAP $install_ldap
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

function save_variable() {
        echo "export $1=$2" >> $variables_file
}

function select_gi_version() {
        local nd_ics_install
        while $(check_input "list" ${gi_version_selected} ${#gi_versions[@]})
        do
                get_input "list" "Select GI version: " "${gi_versions[@]}"
                gi_version_selected="$input_variable"
        done
        msg "Guardium Insights installation choice assumes installation of bundled version of ICS" info
        gi_version_selected=$(($gi_version_selected-1))
        save_variable GI_VERSION $gi_version_selected
        ics_version_selected=${bundled_in_gi_ics_versions[$gi_version_selected]}
        ics_install='Y'
        if [[ $use_air_gap == 'N' ]]
        then
                msg "You can overwrite selection of default ICS ${ics_versions[$ics_version_selected]} version" info
                msg "In this case you must select supported ICS version by GI ${gi_versions[$gi_version_selected]}" info
                msg "Check documentation before to avoid GI installation problems" info
                while $(check_input "yn" ${nd_ics_install})
                do
                        get_input "yn" "Would you like to install non-default Cloud Pak Foundational Services for GI? " true
                        nd_ics_install="${input_variable^^}"
                done
                [[ "$nd_ics_install" == 'Y' ]] && select_ics_version || save_variable GI_ICS_VERSION $ics_version_selected
        else
                display_default_ics
                msg "In case of air-gapped installation you must install the bundled ICS version" info
        fi
}

function select_ics_version() {
	unset ics_install
        ics_version_selected=""
        while $(check_input "yn" ${ics_install})
        do
                get_input "yn" "Would you like to install Cloud Pak Foundational Services (IBM Common Services)? " false
                ics_install=${input_variable^^}
        done
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
                        get_input "es" "Would you provide exact version OC to install (E) or use the latest stable [S]? (E)xact/(\e[4mS\e[0m)table: " true
                        ocp_release_decision=${input_variable^^}
                done
        else
                ocp_release_decision='E'
        fi
        if [[ $ocp_release_decision == 'E' ]]
        then
                msg "Insert minor version of OpenShift ${ocp_major_versions[${ocp_major_version}]}.x" info
                msg "It must be existing version - you can check list of available version using this URL: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/${ocp_major_versions[${ocp_major_version}]}/latest/" info
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

# Switch off the dnf sync for offline installation
function switch_dnf_sync_off() {
        if [[ `grep "metadata_timer_sync=" /etc/dnf/dnf.conf|wc -l` -eq 0 ]]
        then
                echo "metadata_timer_sync=0" >> /etc/dnf/dnf.conf
        else
                sed -i 's/.*metadata_timer_sync=.*/metadata_timer_sync=0/' /etc/dnf/dnf.conf
        fi
}
