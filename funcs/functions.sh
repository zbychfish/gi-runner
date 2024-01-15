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

function display_error() {
        msg "$1" error
        trap - EXIT
        kill -s TERM $MPID
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

function get_network_installation_type() {
	msg "You can deploy OCP with (direct or proxy) or without access to the internet (named as air-gapped, offline, disconnected)" info
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
			printf "\e[31m----------------------------------------\n\e[0m"
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

function save_variable() {
        echo "export $1=$2" >> $variables_file
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
