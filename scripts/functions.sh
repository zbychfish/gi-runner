

function get_bastion_info() {
        msg "Collecting data about bastion" task
        msg "Provide IP address of network interface on bastion which is connected to this same subnet,vlan where the OCP nodes are located" info
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
        msg "Provide the hostname used to resolve bastion name by local DNS which will be set up" info
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
                msg "Provide the IP gateway of subnet where cluster node are located" info
                while $(check_input "ip" ${subnet_gateway})
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
        fi
}

function get_subnets {
	local test=""
	# empty for test
}

function get_network_architecture {
        msg "Network subnet assignment for OCP nodes" task
        msg "OpenShift cluster nodes can be located in the different subnets" info
        msg "If you plan to place individual nodes in separate subnets it is necessary to ensure that DHCP requests are forwarded to the bastion ($bastion_ip) using DHCP relay" info
        msg "It is also recommended to place the bastion outside the subnets used by the cluster" info
        msg "If you cannot setup DHCP relay in your network, all cluster nodes and bastion must be located in this same subnet (DHCP broadcast network)" info
        while $(check_input "yn" "$one_subnet")
        do
                get_input "yn"  "Would you like to place the cluster nodes in one subnet?: " false
                one_subnet=${input_variable^^}
        done
        save_variable GI_ONE_SUBNET $one_subnet
}

function get_ocp_domain() {
        msg "Set cluster domain name" task
        msg "Insert the OCP cluster domain name - it is local cluster, so it doesn't have to be registered as public one" info
        while $(check_input "domain" ${ocp_domain})
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

function prepare_offline_bastion() {
        local curr_password=""
	# empty for test
}

function get_software_architecture() {
        msg "Some important architecture decisions and planned software deployment must be made now" task
        msg "3 nodes only instalation consideration decisions" info
        msg "This kind of architecture has some limitations:" info
        msg "- You cannot isolate storage on separate nodes" info
        msg "- You cannot isolate GI and CPFS" info
        while $(check_input "yn" ${is_master_only})
        do
                get_input "yn" "Is your installation the 3 nodes only? " true
                is_master_only=${input_variable^^}
        done
        save_variable GI_MASTER_ONLY $is_master_only
                msg "Decide what kind of cluster storage option will be implemented:" info
                msg "- OpenShift Data Fountation (OpenShift Container Storage for OCP 4.6-4.8) - commercial rook-ceph branch from RedHat" info
                msg "- Rook-Ceph - opensource cluster storage option" info
                msg "- Portworx Essentials - free version of Portworx Enterprise cluster storage option, it has limitation to 5 workers and 5 TB of storage" info
                while $(check_input "stopx" ${storage_type})
                do
                        get_input "stopx" "Choice the cluster storage type? (O)DF/(\e[4mR\e[0m)ook/(P)ortworx: " true
                        [[ ${input_variable} == '' ]] && input_variable='R'
                        storage_type=${input_variable^^}
                done
        save_variable GI_STORAGE_TYPE $storage_type
        if [[ $storage_type == "O" && $is_master_only == 'N' ]]
        then
                msg "OCS tainting will require minimum 3 additional workers in your cluster to manage cluster storage" info
                while $(check_input "yn" ${ocs_tainted})
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
                while $(check_input "list" ${gi_size_selected} ${#gi_sizes[@]})
                do
                        get_input "list" "Select Guardium Insights deployment template: " "${gi_sizes[@]}"
                        gi_size_selected=$input_variable
                done
                gi_size="${gi_sizes[$((${gi_size_selected} - 1))]}"
                save_variable GI_SIZE_GI $gi_size
        fi
        if [[ $gi_install == "Y" && $is_master_only == 'N' ]]
        then
                msg "DB2 tainting will require additional workers in your cluster to manage Guardium Insights database backend" 8
                while $(check_input "yn" ${db2_tainted})
                do
                        get_input "yn" "Should be DB2 tainted? " true
                        db2_tainted=${input_variable^^}
                done
                save_variable GI_DB2_TAINTED $db2_tainted
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
                msg "In case of air-gapped installation you must install the bundled ICS version" 8
        fi
}

function select_ics_version() {
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

function get_software_selection() {
        while $(check_input "yn" ${gi_install})
        do
                get_input "yn" "Would you like to install Guardium Insights (GI)? " false
                gi_install=${input_variable^^}
        done
        save_variable GI_INSTALL_GI $gi_install
        if [[ $gi_install == 'N' && $use_air_gap == 'N' ]]
        then
                msg "gi-runner offers installation of Cloud Pak for Security (CP4s) - latest version from channel $cp4s_channel" info
                while $(check_input "yn" ${cp4s_install})
                do
                        get_input "yn" "Would you like to install CP4S? " false
                        cp4s_install=${input_variable^^}
                done
                [ $cp4s_install == 'Y' ] && ics_install='N'
        else
                cp4s_install='N'
        fi
        save_variable GI_CP4S $cp4s_install
        [[ $gi_install == 'Y' ]] && select_gi_version
        [[ $cp4s_install == 'N' && $gi_install == 'N' ]] && select_ics_version
        save_variable GI_ICS $ics_install
        select_ocp_version
        while $(check_input "yn" ${install_ldap})
        do
                get_input "yn" "Would you like to install OpenLDAP? " false
                install_ldap=${input_variable^^}
        done
        save_variable GI_INSTALL_LDAP $install_ldap
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
		"dp")
                        read input_variable
                        $3 && input_variable=${input_variable:-D} || input_variable=${input_variable:-P}
                        ;;
		"es")
                        read input_variable
                        $3 && input_variable=${input_variable:-S} || input_variable=${input_variable:-E}
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
                        $3 && msg "(\e[4mN\e[24m)o/(Y)es: " continue || msg "(N)o/(\e[4mY\e[24m)es: " continue
                        read input_variable
                        printf "\e[0m"
                        $3 && input_variable=${input_variable:-N} || input_variable=${input_variable:-Y}
                        ;;
                *)
                        display_error "Unknown get_input function type"
        esac
}

function check_input() {
        case $1 in
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
		"list")
                        if [[ $2 == +([[:digit:]]) ]]
                        then
                                [[ $2 -gt 0 && $2 -le $3 ]] && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
		"stopx")
                        [[ $2 == 'O' || $2 == 'R' || $2 == 'P' ]] && echo false || echo true
                        ;;
		"txt")
                        case $3 in
				"alphanumeric_max64_chars")
                                        [[ $2 =~ ^[a-zA-Z][a-zA-Z0-9]{1,64}$ ]] && echo false || echo true
                                        ;;
                                "2")
                                        [[ ! -z $2 ]] && echo false || echo true
                                        ;;
                                "3")
                                        if [ -z "$2" ] || $(echo "$2" | egrep -q "[[:space:]]" && echo true || echo false)
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
		"yn")
                        [[ $2 == 'N' || $2 == 'Y' ]] && echo false || echo true
                        ;;
                *)
                        display_error "Uknown check_input function type"
        esac
}

function get_network_installation_type() {
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
                msg "Supported Fedora release are ${fedora_supp_releases[*]}" error
                exit 1
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
                "6")
                        printf "\e[32m\e[2mINFO:\e[22m $1\n\e[0m"
                        ;;
                "task")
                        printf "\e[34m\e[2mTASK:\e[22m $1\n\e[0m"
                        ;;
                "info")
                        printf "\e[2mINFO:\e[22m \e[97m$1\n\e[0m"
                        ;;
                "error")
                        printf "\e[31m----------------------------------------\n"
                        if [ "$1" ]
                        then
                                printf "Error: $1\n"
                        else
                                printf "Error in subfunction\n"
                        fi
                        printf -- "----------------------------------------\n"
                        printf "\e[0m"
                        ;;
                *)
                        display_error "msg with incorrect parameter - $2"
                        ;;
        esac
}

function display_error() {
        msg "$1" error
        trap - EXIT
        kill -s TERM $MPID
}

function save_variable() {
        echo "export $1=$2" >> $file
}

