function get_inter_cluster_info() {
        msg "CNI plug-in selection" task
        while $(check_input "sk" ${ocp_cni})
        do
                get_input "sk" "Would you like use default CNI plug-in OpenShift[S]DN or OVN[K]ubernetes(\e[4mS\e[0m)/K): " true
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

function get_px_options() {
	local test=""
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
        #echo $storage_type
        [[ "$storage_type" == 'P' ]] && get_px_options
}

function get_service_assignment() {
        msg "Architecture decisions about service location on cluster nodes" task
        local selected_arr
        local node_arr
        local element
        local rook_on_list
        if [[ $gi_install == 'Y' ]]
        then
                [[ $gi_size == 'values-small' ]] && db2_nodes_size=2 || db2_nodes_size=1
                if [[ $db2_tainted == 'Y' ]]
                then
                        msg "You decided that DB2 will be installed on dedicated node/nodes" info
                        msg "Node/nodes should not be used as storage cluster nodes" info
                else
                        msg "Insert node/nodes name where DB2 should be installed" info
                fi
                msg "DB2 node/nodes should have enough resources (CPU, RAM) to get this role, check GI documentation" info
                msg "Available worker nodes: $worker_name" info
                while $(check_input "nodes" $db2_nodes $worker_name $db2_nodes_size "def")
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
                if [[ "$db2_tainted" == 'N' ]]
                then
                        worker_wo_db2_name=$worker_name
                else
                        for element in ${selected_arr[@]};do node_arr=("${node_arr[@]/$element}");done
                        worker_wo_db2_name=`echo ${node_arr[*]}|tr ' ' ','`
                        workers_for_gi_selection=$worker_wo_db2_name
                fi
        else
                IFS=',' read -r -a node_arr <<< "$worker_name"
                worker_wo_db2_name="${worker_name[@]}"
        fi
        if [[ $storage_type == "R" && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
        then
                msg "You specified Rook-Ceph as cluster storage" info
                msg "You can force to deploy it on strictly defined node list" info
                msg "Only disks from specified nodes will be configured as cluster storage" info
                while $(check_input "yn" $rook_on_list false)
                do
                        get_input "yn" "Would you like to install Rook-Ceph on strictly specified nodes?: " true
                        rook_on_list=${input_variable^^}
                done
                if [ "$rook_on_list" == 'Y' ]
                then
                        msg "Available worker nodes: $worker_wo_db2_name" info
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
                msg "You must specify cluster nodes for OCS deployment" info
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
                save_variable GI_OCS_NODES "$worker_name"
        fi
        if [[ $ics_install == "Y" && $is_master_only == "N" && ${#node_arr[@]} -gt 3 ]]
        then
                msg "You can force to deploy ICS on strictly defined node list" info
                while $(check_input "yn" $ics_on_list false)
                do
                        get_input "yn" "Would you like to install ICS on strictly specified nodes?: " true
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
        fi
        if [ "$gi_install" == 'Y' ]
        then
                IFS=',' read -r -a worker_arr <<< "$worker_name"
                if [[ ( $db2_tainted == 'Y' && ${#node_arr[@]} -gt 3 ) ]] || [[ ( $db2_tainted == 'N' && "$gi_size" == "values-small" && ${#worker_arr[@]} -gt 5 ) ]] || [[ ( $db2_tainted == 'N' && "$gi_size" == "values-dev" && ${#worker_arr[@]} -gt 4 ) ]]
                then
                        msg "You can force to deploy GI on strictly defined node list" 8
                        while $(check_input "yn" $gi_on_list false)
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
                        msg "DB2 node/nodes: $db2_nodes are already on the list included, additionally you must select minimum $no_nodes_2_select node/nodes from the list below:" info
                        msg "Available worker nodes: $workers_for_gi_selection" info
                        while $(check_input "nodes" $gi_nodes $workers_for_gi_selection $no_nodes_2_select "max")
                        do
                                if [ ! -z "$GI_GI_NODES" ]
                                then
                                        get_input "txt" "Push <ENTER> to accept the previous choice [$current_selection] or specify minimum $no_nodes_2_select node/nodes (comma separated, without spaces)?: " true "$current_selection"
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

function get_hardware_info() {
        msg "Collecting hardware information" task
        msg "Automatic CoreOS and storage deployment requires information about NIC and HDD devices" info
        msg "There is assumption that all cluster nodes including bootstrap machine use this isame HW specification" info
        msg "The Network Interface Card (NIC) device specification must provide the one of interfaces attached to each cluster node and connected to cluster subnet" info
        msg "In most cases the first NIC attached to machine will have on Fedora and RedHat the name \"ens192\"" info
        while $(check_input "txt" "${machine_nic}" "non_empty")
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
        msg "There is assumption that all cluster machines use this device specification for boot disk" info
        msg "In most cases the first boot disk will have specification \"sda\" or \"nvmne0\"" info
        msg "The inserted value refers to root path located in /dev" info
        msg "It means that value sda refers to /dev/sda" info
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
}

function set_bastion_ntpd_client() {
        msg "Set NTPD configuration" task
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

function get_worker_nodes() {
        local worker_number=3
        local inserted_worker_number
        if [[ $is_master_only == 'N' ]]
        then
                msg "Collecting workers data" task
                [[ $storage_type == 'P' ]] && max_workers_number=5 || max_workers_number=50
                if [[ $storage_type == 'O' && $ocs_tainted == 'Y' ]]
                then
                        msg "Collecting ODF dedicated nodes data because ODF tainting has been chosen (IP and MAC addresses, node names), values inserted as comma separated list without spaces" task
                        get_nodes_info 3 "ocs"
                fi
                if [[ "$db2_tainted" == 'Y' ]]
                then
                        [[ $gi_size == "values-small" ]] && worker_number=$(($worker_number+2)) || worker_number=$(($worker_number+1))
                fi
                msg "Your cluster architecture decisions require to have minimum $worker_number additional workers" info
                [[ $storage_type == 'P' ]] && msg "Because Portworx Essential will be installed you can specify maximum 5 workers" info
                while $(check_input "int" $inserted_worker_number $worker_number $max_workers_number)
                do
                        get_input "int" "How many additional workers would you like to add to cluster?: " false
                        inserted_worker_number=${input_variable}
                done
                msg "Collecting workers nodes data (IP and MAC addresses, node names), values inserted as comma separated list without spaces" task
                get_nodes_info $inserted_worker_number "wrk"
        fi
}

function get_nodes_info() {
        local temp_ip
        local temp_mac
        local temp_name
        case $2 in
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
                        display_error "Incorrect parameters get_node function"
	esac
}

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
		"sk")
                        read input_variable
                        $3 && input_variable=${input_variable:-S} || input_variable=${input_variable:-K}
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
                                if [ -z "$2" ] || $(echo "$2" | egrep -q "[[:space:]]" && echo true || echo false)
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

