#function get_latest_edr_images () {
        local input_file
        local output_file
        local temp_list
        local image_name
        local image_tag
        local image_tag_last
        declare -a image_types
        input_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-security-edr/${CASE_VERSION}/images-mapping.txt
        output_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-security-edr/${CASE_VERSION}/images-mapping-latest.txt
        msg "Set list of images for download" task
        echo "#list of images to mirror" > $output_file
        while read -r line
        do
                image_name=`echo "$line" | awk -F '@' '{print $1}' | awk -F '/' '{print $NF}'`
                if [[ $image_name =~ 'redis-db'.* || $image_name =~ 'redis-mgmt'.* || $image_name =~ 'redis-proxy'.* || $image_name =~ 'redis-proxylog'.* || $image_name == 'ibm-cloud-databases-redis-operator-bundle' || $image_name == 'ibm-cloud-databases-redis-operator' ]]
                then
                        image_tag=`echo "$line" | awk -F ':' '{print $NF}'`
                        if [[ `echo "$image_tag" | awk -F '-' '{print $(NF-1)}'` == ${edr_redis_release} && (`echo "$image_tag" | awk -F '-' '{print $(NF)}'` == ${edr_redis_release} || `echo "$image_tag" | awk -F '-' '{print $(NF)}'` == "amd64") ]]
                        then
                                echo "$line" >> $output_file
                        fi
                elif [[ `grep -e "s390x" -e "ppc64le" <<< "$line" | wc -l` -eq 0 ]]
                then
                        echo "$line" >> $output_file
                fi
        done < "$input_file"
}

function get_latest_cp4s_images () {
        local input_file
        local output_file
        local temp_list
	local image_name
	local image_tag
	local image_tag_last
        declare -a image_types
        input_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-cp-security/${CASE_VERSION}/images-mapping.txt
        output_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-cp-security/${CASE_VERSION}/images-mapping-latest.txt
        msg "Set list of images for download" task
        echo "#list of images to mirror" > $output_file
        while read -r line
        do
		image_name=`echo "$line" | awk -F '@' '{print $1}' | awk -F '/' '{print $NF}'`
		if [[ $image_name =~ 'redis-db'.* || $image_name =~ 'redis-mgmt'.* || $image_name =~ 'redis-proxy'.* || $image_name =~ 'redis-proxylog'.* || $image_name == 'ibm-cloud-databases-redis-operator-bundle' || $image_name == 'ibm-cloud-databases-redis-operator' ]]
                then
			image_tag=`echo "$line" | awk -F ':' '{print $NF}'`
			if [[ `echo "$image_tag" | awk -F '-' '{print $(NF-1)}'` == ${cp4s_redis_release} && (`echo "$image_tag" | awk -F '-' '{print $(NF)}'` == ${cp4s_redis_release} || `echo "$image_tag" | awk -F '-' '{print $(NF)}'` == "amd64") ]]
			then
				echo "$line" >> $output_file
			fi
		elif [[ `grep -e "s390x" -e "ppc64le" <<< "$line" | wc -l` -eq 0 ]]
		then
                	echo "$line" >> $output_file
                fi
        done < "$input_file"
}

function get_latest_gi_images () {
	local input_file
	local output_file
	local temp_list
	local image_name_redis
	declare -a image_types
	input_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-guardium-insights/${CASE_VERSION}/images-mapping.txt
	output_file=${GI_TEMP}/.ibm-pak/data/mirror/ibm-guardium-insights/${CASE_VERSION}/images-mapping-latest.txt
	msg "Set list of images for download" task
	echo "#list of images to mirror" > $output_file
	while read -r line
	do
		image_name_redis=`echo "$line" | awk -F '@' '{print $1}' | awk -F '/' '{print $NF}'`
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
		elif [[ $image_name_redis =~ 'redis-db'.* || $image_name_redis =~ 'redis-mgmt'.* || $image_name_redis =~ 'redis-proxy'.* || $image_name_redis =~ 'redis-proxylog'.* || $image_name_redis == 'ibm-cloud-databases-redis-operator-bundle' || $image_name_redis == 'ibm-cloud-databases-redis-operator' ]]
		then
			image_tag=`echo "$line" | awk -F ':' '{print $NF}'`
                        if [[ `echo "$image_tag" | awk -F '-' '{print $(NF-1)}'` == ${gi_redis_releases[${gi_version}]} && (`echo "$image_tag" | awk -F '-' '{print $(NF)}'` == ${gi_redis_releases[${gi_version}]} || `echo "$image_tag" | awk -F '-' '{print $(NF)}'` == "amd64") ]]
                        then
                                echo "$line" >> $output_file
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
	[ $cp4s_install == 'Y' ] && { archives+=("CP4S-${cp4s_versions[0]}/registry.tar");descs+=("Cloud Pak for Security (CP4S) ${cp4s_versions[0]}} images");}
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
					elif [ "$archive" == CP4S-${cp4s_versions[0]}/registry.tar ]
                                        then
						msg "Extracting Cloud Pak for Security container images" info
                                                tar -C /opt/registry -xf $gi_archives/$archive
                                                [ $? -ne 0 ] && display_error "Cannot extract content of Cloud Pak image archive"
                                                mkdir -p $GI_TEMP/cp4s_arch
                                                tar -C $GI_TEMP/cp4s_arch -xf $gi_archives/CP4S-${cp4s_versions[0]}/config.tar
                                                [ $? -ne 0 ] && display_error "Cannot extract of Cloud Pak for Security case files"
                                        else
                                                display_error "Problem with extraction of archives, unknown archive type"
                                        fi
                                        ;;
                                *)
                                        display_error "Problem with extraction of archives, check their consistency"
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
	if [ ${script_argument} != 'skip_archives' ]
	then
        	process_offline_archives
        	software_installation_on_offline
	else
		msg "Archives processing skipped" info
	fi
}


function get_mail() {
        curr_value=""
        while $(check_input "mail" "${curr_value}")
        do
                get_input "txt" "$1: " false
                curr_value="$input_variable"
        done
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

function set_bastion_ntpd_client() {
        msg "Set NTPD configuration" task
        sed -i "s/^pool .*/pool $1 iburst/g" /etc/chrony.conf
        systemctl enable chronyd
        systemctl restart chronyd
}


function get_subnets {
	local test=""
	# empty for test
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

