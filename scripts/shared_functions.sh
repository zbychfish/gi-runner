function get_pre_scripts_variables() {
	air_dir=$GI_HOME/air-gap
	host_fqdn=$( hostname --long )
}

function pre_scripts_init() {
	mkdir -p $air_dir
	rm -rf $GI_TEMP
	rm -rf /opt/registry/data
	mkdir -p $GI_TEMP
	dnf -qy install jq
}

function pre_scripts_init_no_jq() {
       	mkdir -p $air_dir
       	rm -rf $GI_TEMP
       	rm -rf /opt/registry/data
       	mkdir -p $GI_TEMP
}

function check_linux_distribution_and_release() {
	msg "Check OS distribution and release" true
        linux_distribution=`cat /etc/os-release | grep ^ID | awk -F'=' '{print $2}'`
        fedora_release=`cat /etc/os-release | grep VERSION_ID | awk -F'=' '{print $2}'`
        is_supported_fedora_release=`case "${fedora_supp_releases[@]}" in  *"${fedora_release}"*) echo 1 ;; *) echo 0 ;; esac`
        if [ $linux_distribution != 'fedora' ]
        then
                msg "ERROR: Only Fedora is supported" true
                exit 1
        fi
        if [ $is_supported_fedora_release -eq 0 ]
        then
                msg "ERROR: Supported Fedora release are ${fedora_supp_releases[*]}" true
                exit 1
        fi
}


function msg() {
        $2 && printf "$1\n" || printf "$1"
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
                "ys")
                        read input_variable
                        $3 && input_variable=${input_variable:-C} || input_variable=${input_variable:-S}
                        ;;
                "sk")
                        read input_variable
                        $3 && input_variable=${input_variable:-S} || input_variable=${input_variable:-K}
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
                "sk")
                        [[ $1 == 'S' || $1 == 'K' ]] && echo false || echo true
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
                                "4")
                                        [[ $1 =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,}[a-zA-Z0-9]$ ]] && echo false || echo true
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
		"mail")
			if [[ "$1" && "$1" =~ ^.*@.*$ ]] 
                        then
				local m_account=$(echo "$1"|awk -F '@' '{print $1}')
				local m_domain=$(echo "$1"|awk -F '@' '{print $2}')
				! $(check_input "$m_account" "txt" 1) && ! $(check_input "$m_domain" "domain") && echo false || echo true
                        else
                                echo true
                        fi
                        ;;
                "*")
                        exit 1
                        ;;
        esac
}

function get_ocp_version_prescript() {
        while $(check_input ${ocp_major_version} "list" ${#ocp_major_versions[@]})
        do
                get_input "list" "Select OCP major version: " "${ocp_major_versions[@]}"
                ocp_major_version=$input_variable
        done
	ocp_major_version=$(($ocp_major_version-1))
        ocp_major_release="${ocp_major_versions[${ocp_major_version}]}"
	if [[ "$1" != "major" ]]
	then
        	msg "Insert minor version of OpenShift ${ocp_major_versions[${ocp_major_version}]}.x" true
        	msg "It must be existing version - you can check the latest stable version using this URL: https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-${ocp_major_versions[${ocp_major_version}]}" true
        	ocp_release_minor=${ocp_release_minor:-Z}
        	while $(check_input ${ocp_release_minor} "int" 0 1000)
        	do
        		get_input "int" "Insert minor version of OCP ${ocp_major_versions[${ocp_major_version}]} to install (must be existing one): " false
                	ocp_release_minor=${input_variable}
        	done
        	ocp_release="${ocp_major_versions[${ocp_major_version}]}.${ocp_release_minor}"
	fi
}

function get_ics_version_prescript() {
	while $(check_input ${ics_version} "list" ${#ics_versions[@]})
        do
                get_input "list" "Select ICS version: " "${ics_versions[@]}"
                ics_version=$input_variable
        done
}

function get_gi_version_prescript() {
	while $(check_input ${gi_version} "list" ${#gi_versions[@]})
        do
                get_input "list" "Select GI version: " "${gi_versions[@]}"
                gi_version=$input_variable
        done
}

function get_pull_secret() {
	msg "You must provide the RedHat account pullSecret to get access to image registries" true
	local is_ok=true
	while $is_ok
        do
	        msg "Push <ENTER> to accept the previous choice" true
                get_input "txt" "Insert RedHat pull secret: " false
                if [ "${input_variable}" ]
                then
                	echo ${input_variable}|{ jq .auths 2>/dev/null 1>/dev/null ;}
                        [[ $? -eq 0 ]] && is_ok=false
                        rhn_secret="${input_variable}"
                fi
	done
}

function get_mail() {
	curr_value=""
	while $(check_input "${curr_value}" "mail")
        do
                get_input "txt" "$1: " false
                curr_value="$input_variable"
        done
}

function get_account() {
	curr_value=""
	while $(check_input "${curr_value}" "txt" 4)
        do
                get_input "txt" "$1: " false
                curr_value="$input_variable"
        done
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

function setup_local_registry() {
	msg "*** Setup Image Registry ***" true
	msg "Installing podman, httpd-tools jq ..."
	dnf -qy install podman httpd-tools
	test $(check_exit_code $?) || (msg "Cannot install httpd-tools" true; exit 1)
	msg "Setup mirror image registry ..." true
	podman stop bastion-registry -i 
	podman container prune <<< 'Y' &>/dev/null
	podman pull docker.io/library/registry:${registry_version} &>/dev/null
	test $(check_exit_code $?) || (msg "Cannot download image registry" true; exit 1)
	mkdir -p /opt/registry/{auth,certs,data}
	openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/bastion.repo.pem -x509 -days 365 -out /opt/registry/certs/bastion.repo.crt -subj "/C=PL/ST=Miedzyrzecz/L=/O=Test /OU=Test/CN=`hostname --long`" -addext "subjectAltName = DNS:`hostname --long`" &>/dev/null
	test $(check_exit_code $?) || (msg "Cannot create certificate for temporary image registry" true; exit 1)
	cp /opt/registry/certs/bastion.repo.crt /etc/pki/ca-trust/source/anchors/
	update-ca-trust extract &>/dev/null
	htpasswd -bBc /opt/registry/auth/htpasswd admin guardium &>/dev/null
	systemctl enable firewalld
	systemctl start firewalld
	firewall-cmd --zone=public --add-port=5000/tcp --permanent &>/dev/null
	firewall-cmd --zone=public --add-service=http --permanent &>/dev/null
	firewall-cmd --reload &>/dev/null
	semanage permissive -a NetworkManager_t &>/dev/null
	msg "Starting image registry ..." true
	podman run -d --name bastion-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/bastion.repo.crt -e REGISTRY_HTTP_TLS_KEY=/certs/bastion.repo.pem docker.io/library/registry:${registry_version} &>/dev/null
	test $(check_exit_code $?) || (msg "Cannot start temporary image registry" true; exit 1)
}

function download_file() {
	msg "Downloading $1 ..." true 
	wget "$1" &>/dev/null
	test $(check_exit_code $?) || (msg "Cannot download $file" true; exit 1)
}

function install_ocp_tools() {
	msg "Install OCP tools ..." true
	tar xf $GI_TEMP/openshift-client-linux.tar.gz -C /usr/local/bin &>/dev/null
	tar xf $GI_TEMP/opm-linux.tar.gz -C /usr/local/bin &>/dev/null
}

function install_app_tools() {
	if [[ $files_type == "ICS" ]]
	then
		tar xf $GI_TEMP/cloudctl-linux-amd64.tar.gz -C /usr/local/bin &>/dev/null
		mv /usr/local/bin/cloudctl-linux-amd64 /usr/local/bin/cloudctl
		tar xf $GI_TEMP/openshift-client-linux.tar.gz -C /usr/local/bin &>/dev/null
	else
		exit 0
	fi
}

