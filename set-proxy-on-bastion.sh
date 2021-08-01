echo "*** Proxy Setup ***"

function get_ocp_domain() {
        if [[ ! -z "$GI_DOMAIN" ]]
        then
                read -p "Cluster domain is set to [$GI_DOMAIN] - insert new or confirm existing one <ENTER>: " new_ocp_domain
                if [[ $new_ocp_domain != '' ]]
                then
                        ocp_domain=$new_ocp_domain
                else
                        ocp_domain=$GI_DOMAIN
                fi
        else
                while [[ $ocp_domain == '' ]]
                do
                        read -p "Insert cluster domain (your private domain name), like ocp.io.priv: " ocp_domain
                        ocp_domain=${ocp_domain:-ocp.io.priv}
                done
        fi
}

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
if [[ $use_proxy == 'P' ]]
then
        get_ocp_domain
        while [[ $proxy_ip == '' ]]
        do
                read -p "HTTP Proxy ip address: " proxy_ip
        done
        while [[ $proxy_port == '' ]]
        do
                read -p "HTTP Proxy port: " proxy_port
        done
        read -p "Insert comma separated list of CIDRs (like 192.168.0.0/24) which should not be proxed (do not need provide here cluster addresses): " no_proxy
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
                sed -i "s/^export no_proxy=.*/export no_proxy=\"127.0.0.1,localhost,*.$ocp_domain,$no_proxy\"/g" /etc/profile
        else
                echo "export no_proxy=\"127.0.0.1,localhost,*.$ocp_domain,$no_proxy\"" >> /etc/profile
        fi
        echo "- Add proxy settings to DNF config file"
        if [ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^proxy=.*/proxy=http:\/\/$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
        else
                echo "proxy=http://$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf
        fi
	echo "To import PROXY settings into current shell execute this command: '. /etc/profile'"
else
	echo "Your system has not been configured to use proxy"
fi


