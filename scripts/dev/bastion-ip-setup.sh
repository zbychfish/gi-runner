#! /bin/bash

clear
echo "This scripts configure static IP address on bastion"
while [[ -z "$nic" || $nic -gt $i ]]
do
	echo $nic
	i=0
	for int in /etc/sysconfig/network-scripts/ifcfg-*
	do
		i=$((i+1)) 
		echo "$i) $int"
	done
	read -p "Which NIC would you like configure? " nic
done
file=`ls /etc/sysconfig/network-scripts/ifc*|head -"$nic"|tail -1`
int=`basename /etc/sysconfig/network-scripts/ifcfg-ens33|awk -F '-' '{ print $2 }'`
if [[ ! -z /etc/sysconfig/network-scripts/orig.ifcfg-${int} ]]
then
	cp /etc/sysconfig/network-scripts/ifcfg-${int} /etc/sysconfig/network-scripts/orig.ifcfg-${int}
fi
while [[ $ip == '' ]]
do
	read -p "Insert bastion IP address: " ip
done
while [[ $mask == '' ]]
do
        read -p "Insert subnet mask (in bit notation, for instance 8, 16, 24: " mask
done
while [[ $gateway == '' ]]
do
        read -p "Insert bastion IP gateway: " gateway
done
while [[ $dns == '' ]]
do
        read -p "Insert local DNS IP address: " dns
done
nmcli connection modify $int IPv4.address ${ip}/${mask}
nmcli connection modify $int IPv4.gateway $gateway
nmcli connection modify $int IPv4.dns $dns
nmcli connection modify $int IPv4.method manual
nmcli connection modify $int connection.autoconnect yes
nmcli device disconnect $int
nmcli device connect $int
