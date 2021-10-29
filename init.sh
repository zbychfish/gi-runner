#!/bin/bash

GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
mkdir -p $GI_TEMP
file=variables.sh
declare -a gi_versions=(3.0.0 3.0.1 3.0.2)
declare -a ics_versions=(3.7.4 3.8.1 3.9.1 3.10.0 3.11.0 3.12.0)
declare -a bundled_in_gi_ics_versions=(0 2 3)
declare -a ocp_major_versions=(4.6 4.7 4.8 4.9)
declare -a ocp_supported_by_gi=(0 0:1 0:1:2)
declare -a ocp_supported_by_ics=(0:1 0:1 0:1:2 0:1:2 0:1:2 0:1:2:3)

echo "# Guardium Insights installation parameters" > $file
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
if [ $use_air_gap == 'Y' ]
then
        echo "export GI_INTERNET_ACCESS=A" >> $file
fi
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
        echo export GI_INTERNET_ACCESS=${use_proxy} >> $file
fi
# GI installation
while ! [[ $gi_install == 'Y' || $gi_install == 'N' ]] # While string is different or empty...
do
        printf "Would you like to install Guardium Insights in this process? (\e[4mN\e[0m)o/(Y)es: "
        read gi_install
        gi_install=${gi_install:-N}
        if ! [[ $gi_install == 'Y' || $gi_install == 'N' ]]
        then
                echo "Incorrect value"
        fi
done
echo "export GI_INSTALL_GI=$gi_install" >> $file
if [[ $gi_install == 'Y' ]]
then
        while [[ $gi_version_selected == '' ]]
        do
                echo "Select GI version:"
                i=1
                for gi_version in "${gi_versions[@]}"
                do
                        echo "$i - $gi_version"
                        i=$((i+1))
                done
                read -p "Your choice?: " gi_version_selected
        	gi_version_selected=$(($gi_version_selected-1))
		(for e in "${gi_versions[@]}"; do [[ "$e" == "${gi_versions[$gi_version_selected]}" ]] && exit 0; done) && is_correct_selection=0 || is_correct_selection=1
	        if [[ $is_correct_selection -ne 0 ]]
        	then
                	gi_version_selected=''
	                echo "Incorrect choice"
        	fi
        done
	echo "Guardium Insights installation choice assumes installation of bundled version of ICS"
	echo "- ICS 3.7.4 for GI 3.0.0"
	echo "- ICS 3.9.0 for GI 3.0.1"
	echo "- ICS 3.10.0 for GI 3.0.2"
	echo "If you would like install different ICS version (supported by selected GI) please modify variable.sh file before starting playbooks"
	echo "In case of air-gapped installation you must install the bundled ICS version"
	echo "export GI_VERSION=$gi_version_selected" >> $file
	ics_version_selected=${bundled_in_gi_ics_versions[$gi_version_selected]}
        echo "export GI_ICS_VERSION=$ics_version_selected" >> $file
else
	while ! [[ $ics_install == 'Y' || $ics_install == 'N' ]] # While string is different or empty...
        do
                printf "Would you like to install IBM Common Services in this process? (\e[4mN\e[0m)o/(Y)es: "
                read ics_install
                ics_install=${ics_install:-N}
                if ! [[ $ics_install == 'Y' || $ics_install == 'N' ]]
                then
                        echo "Incorrect value"
                fi
        done
        echo "export GI_ICS=$ics_install" >> $file
	if [[ $ics_install == 'Y' ]]
        then
                while [[ $ics_version_selected == '' ]]
                do
                        echo "Select ICS version to mirror:"
                        i=1
                        for ics_version in "${ics_versions[@]}"
                        do
                                echo "$i - $ics_version"
                                i=$((i+1))
                        done
                        read -p "Your choice?: " ics_version_selected
                	ics_version_selected=$(($ics_version_selected-1))
			(for e in "${ics_versions[@]}"; do [[ "$e" == "$ics_version_selected" ]] && exit 0; done) && is_correct_selection=0 || is_correct_selection=1
	                if [[ $is_correct_selection -eq 1 ]]
        	        then
                	        ics_version_selected=''
	                echo "Incorrect choice"
        	        fi
                done
                echo "export GI_ICS_VERSION=$ics_version_selected" >> $file
	fi
fi
# OCP selection
if [[ $gi_install == 'Y' ]]
then
	IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_gi[$gi_version_selected]}
elif [[ $ics_install == 'Y' ]]
then
	IFS=':' read -r -a ocp_versions <<< ${ocp_supported_by_ics[$ics_version_selected]}
else
	declare -a ocp_versions=(0 1 2 3)
fi
while [[ $ocp_major_version == '' ]]
do
	echo "Select OCP version:"
	i=1
	for ocp_version in "${ocp_versions[@]}"
	do
		echo "$i - ${ocp_major_versions[$ocp_version]}"
		i=$((i+1))
	done
	read -p "Your choice?: " ocp_major_version
	ocp_major_version=$(($ocp_major_version-1))
	(for e in "${ocp_versions[@]}"; do [[ "$e" == "$ocp_major_version" ]] && exit 0; done) && is_correct_selection=0 || is_correct_selection=1
	if [[ $is_correct_selection -eq 1 ]]
	then
		ocp_major_version=''
		echo "Incorrect choice"
	fi
done
echo $ocp_major_version
