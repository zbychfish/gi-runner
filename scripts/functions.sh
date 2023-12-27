function get_latest_cp4s_images () {
        local input_file
        local output_file
        local temp_list
	local image_name
	local image_tag
        declare -a image_types
        input_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-cp-security/${CASE_VERSION}/images-mapping.txt
        output_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-cp-security/${CASE_VERSION}/images-mapping-latest.txt
        msg "Set list of images for download" task
        echo "#list of images to mirror" > $output_file
        while read -r line
        do
		echo $line
		image_name=`echo "$line" | awk -F '@' '{print $1}' | awk -F '/' '{print $NF}'`
		echo $image_name
		if [[ $image_name =~ 'redis-db'.* || $image_name =~ 'redis-mgmt'.* || $image_name =~ 'redis-proxy'.* || $image_name =~ 'redis-proxylog'.* || $image_name == 'ibm-cloud-databases-redis-operator-bundle' || $image_name == 'ibm-cloud-databases-redis-operator' ]]
                then
			image_tag=`echo "$line" | awk -F '-' '{print $NF}'`
			echo $image_tag
		#else [[ `grep -e "s390x" -e "ppc64le" <<< "$line" | wc -l` -eq 0 ]]
		#	echo 'tutaj'
                #	echo "$line" >> $output_file
                fi
        done < "$input_file"
}

function get_cp4s_options() {
        msg "Collecting CP4S deployment parameters" task
        msg "Namespace define the space where most CP4S pods, objects and supporting services will be located" info
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
        msg "Enter default storage class for CP4S." info
        msg "All CP4S PVC's use RWO access." info
        [ $storage_type == 'R' ] && sc_list=(${rook_sc[@]}) || sc_list=(${ocs_sc[@]})
        while $(check_input "list" ${cp4s_sc_selected} ${#sc_list[@]})
        do
                get_input "list" "Select storage class: " "${sc_list[@]}"
                cp4s_sc_selected=$input_variable
        done
        cp4s_sc="${sc_list[$((${cp4s_sc_selected} - 1))]}"
        save_variable GI_CP4S_SC $cp4s_sc
        msg "Enter default storage class for CP4S backup, it uses RWO access." info
        while $(check_input "list" ${cp4s_sc_backup_selected} ${#sc_list[@]})
        do
                get_input "list" "Select storage class: " "${sc_list[@]}"
                cp4s_sc_backup_selected=$input_variable
        done
        cp4s_sc_backup="${sc_list[$((${cp4s_sc_backup_selected} - 1))]}"
        save_variable GI_CP4S_SC_BACKUP $cp4s_sc_backup
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
        save_variable GI_CP4S_OPTS $(echo ${cp4s_opts[@]}|awk 'BEGIN { FS= " ";OFS="," } { $1=$1 } 1')
}

function configure_os_for_proxy() {
        msg "Configuring proxy settings" task
        msg "To support installation over Proxy some additional information must be gathered and bastion network services reconfiguration" info
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
        no_proxy="127.0.0.1,*.apps.$ocp_domain,*.$ocp_domain,$no_proxy_adds"
        msg "Your proxy settings are:" info
        msg "Proxy URL: http://$proxy_ip:$proxy_port" info
        msg "System will not use proxy for: $no_proxy" info
        msg "Setting your HTTP proxy environment on bastion" info
        msg "- Modyfying /etc/profile" info
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
                sed -i "s#^export no_proxy=.*#export no_proxy=\"$no_proxy\"#g" /etc/profile
        else
                echo "export no_proxy=\"${no_proxy}\"" >> /etc/profile
        fi
        msg "- Add proxy settings to DNF config file" info
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
                "*")
                        display_error "Unknown cert information"
                        ;;
        esac
}

function get_certificates() {
	[[ "$use_air_gap" == 'N' ]] && { msg "Installing openssl ..." info; dnf -y install openssl > /dev/null; }
        msg "Collecting certificates information" task
        msg "You can replace self-signed certicates for UI's by providing your own created by trusted CA" info
        msg "Certificates must be uploaded to bastion to provide full path to them" info
        msg "CA cert, service cert and private key files must be stored separately in PEM format" info
        while $(check_input "yn" "$ocp_ext_ingress" false)
        do
                get_input "yn" "Would you like to install own certificates for OCP?: " true
                ocp_ext_ingress=${input_variable^^}
        done
        save_variable GI_OCP_IN $ocp_ext_ingress
        [ $ocp_ext_ingress == 'Y' ] && validate_certs "ocp"
        if [[ "$gi_install" == 'Y' || "$ics_install" == 'Y' ]]
        then
                while $(check_input "yn" "$ics_ext_ingress" false)
                do
                        get_input "yn" "Would you like to install own certificates for ICP?: " true
                        ics_ext_ingress=${input_variable^^}
                done
                save_variable GI_ICS_IN $ics_ext_ingress
                [ $ics_ext_ingress == 'Y' ] && validate_certs "ics"
        fi
        if [[ "$gi_install" == 'Y' ]]
        then
                while $(check_input "yn" "$gi_ext_ingress" false)
                do
                        get_input "yn" "Would you like to install own certificates for GI?: " true
                        gi_ext_ingress=${input_variable^^}
                done
                save_variable GI_IN $gi_ext_ingress
                [ $gi_ext_ingress == 'Y' ] && validate_certs "gi"
        fi
        if [[ "$cp4s_install" == 'Y' && "$use_air_gap" == 'N' ]]
        then
                while $(check_input "yn" "$cp4s_ext_ingress" false)
                do
                        get_input "yn" "Would you like to install own certificates for CP4S?: " true
                        cp4s_ext_ingress=${input_variable^^}
                done
                save_variable GI_CP4S_IN $cp4s_ext_ingress
                [ $cp4s_ext_ingress == 'Y' ] && validate_certs "cp4s"
        fi
}

function get_latest_gi_images () {
	local input_file
	local output_file
	local temp_list
	declare -a image_types
	input_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-guardium-insights/${CASE_VERSION}/images-mapping.txt
	output_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-guardium-insights/${CASE_VERSION}/images-mapping-latest.txt
	msg "Set list of images for download" task
	echo "#list of images to mirror" > $output_file
	while read -r line
	do
		if [ $(echo "$line" | awk -F '@' '{print $1}' | awk -F '/' '{print $(NF-1)}') == 'ibm-guardium-insights' ]
		then
			declare -a temp_list
			image_name=`echo "$line" | awk -F '@' '{print $1}' | awk -F '/' '{print $(NF)}'`
			image_release=`echo "$line" | awk -F ':' '{print $4}' | awk -F '-' '{print $2}'` 
			temp_list+=(${image_release:1})
			if [ `grep "${image_name}:release" $output_file | wc -l` -eq 0 ]
			then
				echo "$line" >> $output_file
			else
				saved_image_release=`grep "${image_name}:release" $output_file | awk -F ':' '{print $4}' | awk -F '-' '{print $2}'`
				temp_list+=(${saved_image_release:1})
				newest_image=`printf '%s\n' "${temp_list[@]}" | sort -V | tail -n 1`
				unset temp_list
				if [ $newest_image != ${saved_image_release:1} ]
				then
					sed -i "/.*${image_name}:release-${saved_image_release}.*/d" $output_file
					echo "$line" >> $output_file
				fi
			fi
		else
			if [ `grep -e "s390x" -e "ppc64le" <<< "$line" | wc -l` -eq 0 ]
			then
				echo "$line" >> $output_file
			fi
		fi
	done < "$input_file"
}

function get_gi_version_prescript() {
        while $(check_input "list" ${gi_version} ${#gi_versions[@]})
        do
                get_input "list" "Select GI version: " "${gi_versions[@]}"
                gi_version=$input_variable
        done
}

function install_app_tools() {
        if [[ $files_type == "ICS" ]]
        then
                tar xf $GI_TEMP/cloudctl-linux-amd64.tar.gz -C /usr/local/bin &>/dev/null
                mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl
                tar xf $GI_TEMP/openshift-client-linux.tar.gz -C /usr/local/bin &>/dev/null
	elif [[ $files_type == "GI" || $files_type == "CP4S" ]]
	then
		tar xf $GI_TEMP/openshift-client-linux.tar.gz -C /usr/local/bin &>/dev/null
		tar xf $GI_TEMP/oc-ibm_pak-linux-amd64.tar.gz -C /usr/local/bin &>/dev/null
		mv /usr/local/bin/oc-ibm_pak-linux-amd64 /usr/local/bin/oc-ibm_pak

        else
                display_error "Unknown operation type in install_app_tools function"
        fi
}

function get_account() {
        curr_value=""
        while $(check_input "txt" "${curr_value}" "non_empty" )
        do
                get_input "txt" "$1: " false
                curr_value="$input_variable"
        done
}

function get_ics_version_prescript() {
        while $(check_input "list" ${ics_version} ${#ics_versions[@]})
        do
                get_input "list" "Select ICS version: " "${ics_versions[@]}"
                ics_version=$input_variable
        done
}

function software_installation_on_offline() {
        local is_updated
        msg "Update and installation of software packaged" task
        if [[ `uname -r` != `cat $GI_TEMP/os/kernel.txt` ]]
        then
                msg "Kernel of air-gap bastion differs from air-gap file generator!" info
                msg "In most cases the independent kernel update will lead to problems with system libraries" info
                while $(check_input "yn" ${is_updated})
                do
                        get_input "yn" "Have you updated system before, would you like to continue? " true
                        is_updated=${input_variable^^}
                done
                if [ $is_updated != 'Y' ]
                then
                        display_error "Upload air-gap files corresponding to bastion kernel or generate files for bastion environmenti first"
                fi
        fi
        msg "Installing OS updates" info
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os/os-updates/*rpm --allowerasing
        msg "Installing OS packages" info
        dnf -qy --disablerepo=* localinstall ${GI_TEMP}/os/os-packages/*rpm --allowerasing
        msg "Installing Ansible and python modules" info
        cd ${GI_TEMP}/os/ansible
        pip3 install passlib-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install dnspython-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install beautifulsoup4-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install argparse-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install jmespath-* --no-index --find-links '.' > /dev/null 2>&1
        pip3 install soupsieve-* --no-index --find-links '.' > /dev/null 2>&1
        cd $GI_TEMP/os/galaxy
        ansible-galaxy collection install community-general-${galaxy_community_general}.tar.gz
        ansible-galaxy collection install ansible-utils-${galaxy_ansible_utils}.tar.gz
        ansible-galaxy collection install community-crypto-${galaxy_community_crypto}.tar.gz
        ansible-galaxy collection install containers-podman-${galaxy_containers_podman}.tar.gz
        cd $GI_HOME
        mkdir -p /etc/ansible
        echo -e "[bastion]\n127.0.0.1 ansible_connection=local" > /etc/ansible/hosts
        msg "OS software update and installation successfully finished" info
}

function process_offline_archives() {
        msg "Extracting archives - this process can take several minutes and even hours, be patient ..." task
        local archive
        local archives=("os-Fedora_release_*" "${ocp_release}/ocp-tools.tar" "additions-registry-*")
        local descs=('Fedora files' "Openshift ${ocp_release} files" "OpenLDAP, NFS provisioner images")
        [ $storage_type == 'R' ] && { archives+=("rook-registry-${rook_version}.tar");descs+=("Rook-Ceph ${rook_version} images");}
        [ $gi_install == 'Y' ] && { archives+=("GI-${gi_versions[$gi_version_selected]}/registry.tar");descs+=("Guardium Insights ${gi_versions[$gi_version_selected]}} images");}
        [[ $ics_install == 'Y' && $gi_install == 'N' ]] && { archives+=("ics_registry-${ics_versions[$ics_version_selected]}.tar");descs+=("Common Services ${ics_versions[$ics_version_selected]} images");}
        local i=0
        for archive in ${archives[@]}
        do
		msg "Processing archive $archive" task
                if [ -e ${gi_archives}/${archive} ] && [ $(ls ${gi_archives}/${archive}|wc -l) -eq 1 ]
                then
                        case $i in
                                0)
                                        msg "Extracting Fedora software packages" info
                                        mkdir -p $GI_TEMP/os
                                        tar -C $GI_TEMP/os -xf ${gi_archives}/$archive kernel.txt ansible/* galaxy/* os-packages/* os-updates/*
                                        [ $? -ne 0 ] && display_error "Cannot extract content of operating system packages"
                                        ;;
                                1)
                                        msg "Extracting CoreOS images, OCP container images and tools" info
                                        mkdir -p $GI_TEMP/coreos
                                        tar -C $GI_TEMP/coreos -xf $gi_archives/$archive oc-registry.tar openshift-client-linux.tar.gz openshift-install-linux.tar.gz rhcos-live-initramfs.x86_64.img rhcos-live-kernel-x86_64 rhcos-live-rootfs.x86_64.img "matchbox-v${matchbox_version}-linux-amd64.tar.gz" oc-mirror.tar.gz
                                        [ $? -ne 0 ] && display_error "Cannot extract content from Openshift archive"
                                        tar -C $GI_TEMP/coreos -xf $gi_archives/${ocp_release}/ocp-images-yamls.tar
                                        [ $? -ne 0 ] && display_error "Cannot extract content from Openshift images yaml files"
					mkdir -p /opt/registry/data
                                        tar -C /opt/registry -xf $gi_archives/${ocp_release}/ocp-images-data.tar data/*
                                        [ $? -ne 0 ] && display_error "Cannot extract OCP images"
                                        ;;
				2)
					msg "Extracting OpenLDAP and NFS container images" info
					tar -C /opt/registry -xf $gi_archives/$archive data/*
                                        [ $? -ne 0 ] && display_error "Cannot extract OpenLDAP and NFS images"
					mkdir -p $GI_TEMP/adds
					tar -C $GI_TEMP/adds -xf $gi_archives/$archive digests.txt
                                        [ $? -ne 0 ] && display_error "Cannot extract OpenLDAP and OCP digests"
					;;
                                3|4|5|6)
					mkdir -p /opt/registry/data
                                        if [ "$archive" == rook-registry-${rook_version}.tar ]
                                        then
                                                mkdir -p $GI_TEMP/rook
                                                msg "Extracting Rook-Ceph container images" info
                                                tar -C $GI_TEMP/rook -xf $gi_archives/$archive rook_images_sha
                                                tar -C /opt/registry -xf $gi_archives/$archive data/*
                                                [ $? -ne 0 ] && display_error "Cannot extract content of Rook-Ceph archive"
                                        elif [ "$archive" == GI-${gi_versions[$gi_version_selected]}/registry.tar ]
                                        then
                                                msg "Extracting Guardium Insights container images" info
                                                tar -C /opt/registry -xf $gi_archives/$archive
                                                [ $? -ne 0 ] && display_error "Cannot extract content of Guardium Insights image archive"
                                                mkdir -p $GI_TEMP/gi_arch
                                                tar -C $GI_TEMP/gi_arch -xf $gi_archives/GI-${gi_versions[$gi_version_selected]}/config.tar
                                                [ $? -ne 0 ] && display_error "Cannot extract of Guardium Insights case files"
                                        elif [ "$archive" == ics_registry-${ics_versions[$ics_version_selected]}.tar ]
                                        then
                                                msg "Extracting Common Services container images" info
                                                mkdir -p $GI_TEMP/ics_arch
                                                tar -C $GI_TEMP/ics_arch -xf $gi_archives/$archive cloudctl-linux-amd64.tar.gz ics_offline/*
                                                tar -C /opt/registry -xf $gi_archives/$archive data/*
                                                [ $? -ne 0 ] && display_error "Cannot extract content of Common Services archive"
                                        else
                                                display_error "Problem with extraction of archives, unknown archive type"
                                        fi
                                        ;;
                                *)
                                        display_error "Problem with extraction of archives, check their consitency"
                                        ;;
                        esac

                else
                        display_error "Cannot find the ${descs[$i]} archive, please copy to archive to ${gi_archives} directory and restart init.sh"
                fi
                i=$(($i+1))
        done
}

function prepare_offline_bastion() {
        local curr_password=""
        msg "Bastion preparation to managed installation offline (air-gapped)" task
        msg "Offline installation requires setup the local image repository on bastion" info
        while $(check_input "txt" "${repo_admin}" "non_empty")
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
        input_variable=true
        while $input_variable
        do
                if [ ! -z "$GI_REPO_USER_PWD" ]
                then
                        get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_REPO_USER_PWD] or insert new password for $repo_admin user: " true "$GI_REPO_USER_PWD"
                else
                        get_input "pwd" "Insert new password for $repo_admin user: " false
                fi
        done
        save_variable GI_REPO_USER_PWD "'$curr_password'"
        msg "Offline installation requires installation archives preparation using preinstall scripts" info
        msg "Archives must be copied to bastion before installation" info
        while $(check_input "dir" "${gi_archives}")
        do
                if [[ ! -z "$GI_ARCHIVES_DIR" ]]
                then
                        get_input "txt" "Push <ENTER> to accept the previous choice [$GI_ARCHIVES_DIR] or insert the full path to installation archives: " true "$GI_ARCHIVES_DIR"
                else
                        get_input "txt" "Insert full path to installation archives (default location - $GI_HOME/download): " true "$GI_HOME/download"
                fi
                        gi_archives="${input_variable}"
        done
        save_variable GI_ARCHIVES_DIR "'$gi_archives'"
        process_offline_archives
        software_installation_on_offline
}

function install_ocp_tools() {
        msg "Installing OCP tools ..." task
        tar xf $GI_TEMP/openshift-client-linux.tar.gz -C /usr/local/bin &>/dev/null
        tar xf $GI_TEMP/oc-mirror.tar.gz -C /usr/local/bin &>/dev/null
	chmod +x /usr/local/bin/oc-mirror
}

function download_file() {
        msg "Downloading $1 ..." info
        wget "$1" &>/dev/null
        test $(check_exit_code $?) || (msg "Cannot download $file" true; exit 1)
}

function setup_local_registry() {
        msg "*** Setup Image Registry ***" task
        msg "Installing podman, httpd-tools, openssl, jq, policycoreutils-python-utils, wget ..." task
        dnf -qy install podman httpd-tools openssl jq policycoreutils-python-utils wget
        test $(check_exit_code $?) || (msg "Cannot install httpd-tools" info; exit 1)
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
        htpasswd -bBc /opt/registry/auth/htpasswd admin guardium &>/dev/null
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --zone=public --add-port=5000/tcp --permanent &>/dev/null
        firewall-cmd --zone=public --add-service=http --permanent &>/dev/null
        firewall-cmd --reload &>/dev/null
        semanage permissive -a NetworkManager_t &>/dev/null
        msg "Starting image registry ..." task
        podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:${registry_version} &>/dev/null
        test $(check_exit_code $?) || (msg "Cannot start temporary image registry" info; exit 1)
}

function get_mail() {
        curr_value=""
        while $(check_input "mail" "${curr_value}")
        do
                get_input "txt" "$1: " false
                curr_value="$input_variable"
        done
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

function check_exit_code() {
        if [[ $1 -ne 0 ]]
        then
                msg $2 info
                msg "Please check the reason of problem and restart script" info
                echo false
        else
                echo true
        fi
}

function get_pre_scripts_variables() {
        air_dir=$GI_HOME/air-gap
        host_fqdn=$( hostname --long )
}

function pre_scripts_init() {
        mkdir -p $air_dir
        rm -rf $GI_TEMP || msg "$GI_TEMP cannot be removed" info
        rm -rf /opt/registry/data
        mkdir -p $GI_TEMP
        dnf -qy install jq
}

function pre_scripts_init_no_jq() {
        mkdir -p $air_dir
        rm -rf $GI_TEMP || msg "$GI_TEMP cannot be removed" info
        rm -rf /opt/registry/data
        mkdir -p $GI_TEMP
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
                        size_min=200
                        [[ "gi_size" != "values-dev" ]] && v_aux1=2 || v_aux=1
                        m_desc="DB2 DATA pvc - stores activity events, installation proces will create $v_aux1 PVC/PVC's, each instance contains different data"
                        m_ask="DB2 DATA pvc, minium size $size_min GB"
                        global_var="GI_DATA_STORAGE_SIZE"
                        global_var_val="$GI_DATA_STORAGE_SIZE"
                        ;;
                "db2-meta")
                        size_min=30
                        m_desc="DB2 METADATA pvc - stores DB2 shared, temporary, tool files, installation proces will create 1 PVC"
                        m_ask="DB2 METADATA pvc, minimum size $size_min GB"
                        global_var="GI_METADATA_STORAGE_SIZE"
                        global_var_val="$GI_METADATA_STORAGE_SIZE"
                        ;;
                "db2-logs")
                        size_min=50
                        [[ "gi_size" != "values-dev" ]] && v_aux1=2 || v_aux=1
                        m_desc="DB2 ARCHIVELOG pvc - stores DB2 archive logs, 1 PVC"
                        m_ask="DB2 ARCHIVELOG pvc, minium size $size_min GB"
                        global_var="GI_ARCHIVELOGS_STORAGE_SIZE"
                        global_var_val="$GI_ARCHIVELOGS_STORAGE_SIZE"
                        ;;
		"db2-temp")
                        size_min=50
                        [[ "gi_size" != "values-dev" ]] && v_aux1=2 || v_aux=1
                        m_desc="DB2 TEMPTS pvc - temporary objects space in DB2, installation process will create $v_aux1 PVC/PVC's, each instance contains different data"
                        m_ask="DB2 TEMPTS pvc, minium size $size_min GB"
                        global_var="GI_TEMPTS_STORAGE_SIZE"
                        global_var_val="$GI_TEMPTS_STORAGE_SIZE"
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
                        size_min=2
                        [[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
                        m_desc="ZOOKEEPER pvc - stores Kafka configuration and health data, installation process will create $v_aux1 PVC/PVC's, each instance contains this same data"
                        m_ask="ZOOKEEPER pvc, minium size $size_min GB"
                        global_var="GI_ZOOKEEPER_STORAGE_SIZE"
                        global_var_val="$GI_ZOOKEEPER_STORAGE_SIZE"
                        ;;
		"redis")
                        size_min=5
                        [[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
                        m_desc="REDIS pvc - stores Redis configuration and cached session data, installation process will create $v_aux1 PVC/PVC's, each instance contains this same data"
                        m_ask="REDIS pvc, minium size $size_min GB"
                        global_var="GI_REDIS_STORAGE_SIZE"
                        global_var_val="$GI_REDIS_STORAGE_SIZE"
                        ;;
		"pgsql")
                        size_min=5
                        [[ "gi_size" != "values-dev" ]] && v_aux1=3 || v_aux=1
                        m_desc="POSTGRES pvc - stores anomalies and analytics data, installation process will create $v_aux1 PVC/PVC's, each instance contains this same data"
                        m_ask="POSTGRES pvc, minium size $size_min GB"
                        global_var="GI_POSTGRES_STORAGE_SIZE"
                        global_var_val="$GI_POSTGRES_STORAGE_SIZE"
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

function get_gi_pvc_size() {
        local custom_pvc
        msg "The cluster storage contains 3 disks - ${storage_device_size} GB each" info
        [[ "$storage_type" == 'O' ]] && msg "OCS creates 3 copies of data chunks so you have ${storage_device_size} of GB effective space for PVC's" info || msg "Rook-Ceph creates 2 copies of data chunks so you have $((2*${storage_device_size})) GB effective space for PVC's" info
        while $(check_input "yn" "$custom_pvc")
        do
                get_input "yn" "Would you like customize Guardium Insights PVC sizes (default) or use default settings?: " false
                custom_pvc=${input_variable^^}
        done
        if [ $custom_pvc == 'Y' ]
        then
                pvc_arr=("db2-data" "db2-meta" "db2-logs" "db2-temp" "mongo-data" "mongo-logs" "kafka" "zookeeper" "redis" "pgsql")
                for pvc in ${pvc_arr[@]};do pvc_sizes $pvc;done
        else
                local pvc_variables=("GI_DATA_STORAGE_SIZE" "GI_METADATA_STORAGE_SIZE" "GI_ARCHIVELOGS_STORAGE_SIZE" "GI_TEMPTS_STORAGE_SIZE" "GI_MONGO_DATA_STORAGE_SIZE" "GI_MONGO_METADATA_STORAGE_SIZE" "GI_KAFKA_STORAGE_SIZE" "GI_ZOOKEEPER_STORAGE_SIZE" "GI_REDIS_STORAGE_SIZE" "GI_POSTGRES_STORAGE_SIZE")
                for pvc in ${pvc_variables[@]};do save_variable $pvc 0;done
        fi
}

function get_gi_options() {
        local change_ssh_host
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
                get_input "yn" "Should be DB2u tablespace encrypted?: " true
                db2_enc=${input_variable^^}
        done
        save_variable GI_DB2_ENCRYPTED $db2_enc
        while $(check_input "yn" "$stap_supp" false)
        do
                get_input "yn" "Should be enabled the direct streaming from STAP's and Outliers engine?: " false
                stap_supp=${input_variable^^}
        done
        save_variable GI_STAP_STREAMING $stap_supp
        while $(check_input "yn" "$outliers_demo" false)
        do
        	get_input "yn" "Should the Outliers engine work in demo mode?: " false
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
                        get_input "txt" "Insert IP address of Load Balancer to which datamarts should be redirected: " false
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
                        get_input "txt" "Insert port number used on Load Balancer to transfer datamarts to GI: " true
                        ssh_port=${input_variable}
                done
                save_variable GI_SSH_PORT $ssh_port
        else
                save_variable GI_SSH_PORT "0"
        fi
	msg "GI Backup approach" task
	msg "There is possible to use NFS based cluster storage for GI backups" info
	while $(check_input "yn" "$use_nfs_backup" false)
	do
		get_input "yn" "Would you like to configure GI backups using NFS storage?: " true
                use_nfs_backup=${input_variable^^}
        done
	save_variable GI_NFS_BACKUP $use_nfs_backup
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
	fi
}

function get_ldap_options() {
        msg "Collecting OpenLDAP deployment parameters" task
        while $(check_input "cs" "$ldap_depl")
        do
                get_input "cs" "Decide where LDAP instance should be deployed as Container on OpenShift (default) or as Standalone installation on bastion:? (\e[4mC\e[0m)ontainer/Ba(s)tion " true
                ldap_depl=${input_variable^^}
        done
        save_variable GI_LDAP_DEPLOYMENT $ldap_depl
        msg "Define LDAP domain distinguished name, only DC components are allowed" info
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

function get_ics_options() {
        msg "Collecting Common Services parameters" task
        local operand
        local curr_op
        msg "ICS provides possibility to define which services will be deployed, some of them are required by CP4S and GI and will installed as default, the others are optional." info
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

function create_cluster_ssh_key() {
        msg "Add a new RSA SSH key" task
        cluster_id=$(mktemp -u -p ~/.ssh/ cluster_id_rsa.XXXXXXXXXXXX)
        msg "*** Cluster key: ~/.ssh/${cluster_id}, public key: ~/.ssh/${cluster_id}.pub ***" info
        ssh-keygen -N '' -f ${cluster_id} -q <<< y > /dev/null
        echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null" > ~/.ssh/config
        cat ${cluster_id}.pub >> /root/.ssh/authorized_keys
        save_variable GI_SSH_KEY "${cluster_id}"
        msg "Save SSH keys names: ${cluster_id} and ${cluster_id}.pub, each init.sh execution create new key with random name" info
}

function software_installation_on_online() {
        msg "Update and installation of software packages" task
        msg "Installing OS updates, takes a few minutes" task
        dnf -qy update
        msg "Installing OS packages" task
        for package in "${linux_soft[@]}"
        do
                msg "- installing $package ..." info
                dnf -qy install $package &>/dev/null
                [[ $? -ne 0 ]] && display_error "Cannot install $package"
        done
        msg "Installing Python packages" task
        for package in "${python_soft[@]}"
        do
                msg "- installing $package ..." info
                [[ $use_proxy == 'D' ]] && pip3 install "$package" || pip3 install "$package" --proxy http://$proxy_ip:$proxy_port
                [[ $? -ne 0 ]] && display_error "Cannot install python package $package"
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
        mkdir -p ${GI_TEMP}/os
        echo "pullSecret: '$rhn_secret'" > ${GI_TEMP}/os/pull_secret.tmp
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
                if [[ $gi_install == 'Y' || $cp4s_install == 'Y' ]]
                then
                        msg "GI and CP4S require access to restricted IBM image registries" info
                        msg "You need provide the IBM Cloud containers key located at URL - https://myibm.ibm.com/products-services/containerlibrary" info
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
                msg "Define ICS admin user password" info
                msg "This same account is used by GI for default account with access management role" info
                while $(check_input "txt" "${ics_password}" "non_empty")
                do
                        if [ ! -z "$GI_ICSADMIN_PWD" ]
                        then
                                get_input "pwd" "Push <ENTER> to accept the previous choice [$GI_ICSADMIN_PWD] or insert ICS admin user password: " true "$GI_ICSADMIN_PWD"
                        else
                                get_input "pwd" "Insert ICS admin user password: " false
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
		[[ $is_master_only == 'Y' ]] && available_nodes=$master_name || available_nodes=$worker_name 
		msg "$master_name, $available_nodes" info
                if [[ $db2_tainted == 'Y' ]]
                then
                        msg "You decided that DB2 will be installed on dedicated node/nodes" info
                        msg "Node/nodes should not be used as storage cluster nodes" info
                else
                        msg "Insert node/nodes name where DB2 should be installed" info
                fi
                msg "DB2 node/nodes should have enough resources (CPU, RAM) to get this role, check GI documentation" info
                msg "Available worker nodes: $available_nodes" info
                while $(check_input "nodes" $db2_nodes $available_nodes $db2_nodes_size "def")
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
                        msg "You can force to deploy GI on strictly defined node list" info
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
                msg "- OpenShift Data Fountation - commercial rook-ceph branch from RedHat" info
                msg "- Rook-Ceph - opensource cluster storage option" info
                msg "- Portworx Essentials - free version of Portworx Enterprise cluster storage option, it has limitation to 5 workers and 5 TB of storage" info
                while $(check_input "stopx" ${storage_type})
                do
                        get_input "stopx" "Choice the cluster storage type? (O)DF/(\e[4mR\e[0m)ook/(P)ortworx: " true
                        [[ ${input_variable} == '' ]] && input_variable='R'
                        storage_type=${input_variable^^}
                done
        save_variable GI_STORAGE_TYPE $storage_type
        if [[ $storage_type == "O" && $is_master_only == 'N' && false ]] # check tainting
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
                msg "DB2 tainting will require additional workers in your cluster to manage Guardium Insights database backend" info
                while $(check_input "yn" ${db2_tainted})
                do
                        get_input "yn" "Should be DB2 tainted? " true
                        db2_tainted=${input_variable^^}
                done
                save_variable GI_DB2_TAINTED $db2_tainted
	else
		save_variable GI_DB2_TAINTED "N"
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
                msg "In case of air-gapped installation you must install the bundled ICS version" info
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

