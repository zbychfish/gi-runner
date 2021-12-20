#!/bin/bash

GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
mkdir -p $GI_TEMP

# Get information about environment type (Air-Gapped, Proxy, Direct access to the internet)
echo "*** Air-Gapped Setup ***"
while ! [[ $use_air_gap == 'Y' || $use_air_gap == 'N' ]] # While string is different or empty...
do
        printf "Is your environment air-gapped? (\e[4mN\e[0m)o/(Y)es: "
        read use_air_gap
        use_air_gap=${use_air_gap:-N}
        if ! [[ $use_air_gap == 'Y' || $use_air_gap == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
if [[ $use_air_gap == 'N' ]]
then
        echo "*** Proxy Setup ***"
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
fi
# Configure bastion to use proxy
if [[ $use_proxy == 'P' ]]
then
        ocp_domain=get_ocp_domain
        while [[ $proxy_ip == '' ]]
        do
                read -p "HTTP Proxy ip address: " proxy_ip
        done
        while [[ $proxy_port == '' ]]
        do
                read -p "HTTP Proxy port: " proxy_port
        done
        echo "Your proxy settings are:"
        echo "Proxy URL: http://$proxy_ip:$proxy_port"
        if [ `cat /etc/dnf/dnf.conf | grep "proxy=" | wc -l` -ne 0 ]
        then
                sed -i "s/^proxy=.*/proxy=http:\/\/$proxy_ip:$proxy_port/g" /etc/dnf/dnf.conf
        else
                echo "proxy=http://$proxy_ip:$proxy_port" >> /etc/dnf/dnf.conf
        fi
fi
# Install TAR on core base Centos
echo $GI_HOME
if [ `dnf list tar --installed 2>/dev/null|tail -n1|wc -l` -eq 0 ]
then
        if [ $use_air_gap == 'Y' ]
        then
                if [ `ls $GI_HOME/download/tar.cpio|wc -l` -ne 0 ]
                then
                        cd $GI_TEMP
                        cpio -idv -F ${GI_HOME}/download/tar.cpio
                        dnf -qy --disablerepo=* localinstall tar-install/*rpm --allowerasing
                        cd $GI_HOME
                else
                        echo "Cannot find tar.cpio in download directory!"
                        exit 1
                fi
	else
		dnf -qy install tar unzip
        fi
fi
rm -rf $GI_TEMP
