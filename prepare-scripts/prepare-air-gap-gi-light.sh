#!/bin/bash
set -e
trap "exit 1" ERR

echo "Setting environment"
if [[ $# -ne 0 && $1 != "repeat" ]]
then
	echo "To restart mirroring process use paramater 'repeat'"
	exit 1
fi

source scripts/init.globals.sh
source scripts/shared_functions.sh

get_pre_scripts_variables
if [ $# -eq 0 ]
then
	pre_scripts_init
fi
get_gi_version_prescript
gi_version=$(($gi_version-1))

if [ $# -eq 0 ]
then
	echo "Cleanup temp directory $temp_dir"
	rm -rf $GI_TEMP
	mkdir -p $GI_TEMP
	mkdir -p $air_dir
fi
read -sp "Insert your IBM Cloud Key: " ibm_account_key
if [ $# -eq 0 ]
then
	msg "Setup mirror image registry ..." true
	setup_local_registry
	msg "Download support tools ..." true
	cd $GI_TEMP
	declare -a ocp_files=("https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz")
	for file in ${ocp_files[@]}
	do
        	download_file $file
	done
	files_type="ICS"
	install_app_tools
	dnf -qy install skopeo
	check_exit_code $? "Cannot install skopeo package"
fi
b64auth=$( echo -n 'admin:guardium' | openssl base64 )
LOCAL_REGISTRY="$host_fqdn:5000"
echo "Mirroring GI ${gi_versions[${gi_version}]}"
CASE_ARCHIVE=${gi_cases[${gi_version}]}
CASE_INVENTORY_SETUP=install
if [ $# -eq 0 ]
then
	cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/${CASE_ARCHIVE} --outputdir $GI_TEMP/gi_offline
	check_exit_code $? "Cannot download GI case file"
	skopeo login cp.icr.io -u cp -p $ibm_account_key
	skopeo login $(hostname --long):5000 -u admin -p guardium
fi
list_csv=$(ls $GI_TEMP/gi_offline/*images.csv)
for csv in $list_csv
do
        echo "CSV file: $csv"
        images=$(cat ${csv}|tail -n +2)
        for image in $images
        do
                #echo "IMAGE: $image"
                if [[ $(echo $image|awk -F "," '{print $7}') == "amd64"|| $(echo $image|awk -F "," '{print $7}') == "x86_64" || $(echo $image|awk -F "," '{print $5}') == "LIST" ]]
                then
			if [[ $csv =~ .*ibm-guardium-insights.* && ($(echo $image|awk -F "," '{print $3}') =~ .*v${gi_versions[${gi_version}]}.* || $(echo $image|awk -F "," '{print $3}') =~ .*v${gi_versions[$((gi_version-1))]}.*) ]]
                        then
                                echo $image
				skopeo copy --retry-times=10 --all docker://$(echo $image|awk -F "," '{print $1"/"$2"@"$4}') docker://$(hostname --long):5000\/$(echo $image|awk -F "," '{print $2":"$3}') --tls-verify=false
                        elif [[ ! $csv =~ .*ibm-guardium-insights.* ]]
                        then
                                echo $image
				skopeo copy --retry-times=10 --all docker://$(echo $image|awk -F "," '{print $1"/"$2"@"$4}') docker://$(hostname --long):5000\/$(echo $image|awk -F "," '{print $2":"$3}') --tls-verify=false
                        fi
                fi
                [ $? -ne 0 ] && exit 1
        done
done
podman stop bastion-registry
cd $GI_TEMP
tar cf ${air_dir}/gi_registry-${gi_versions[${gi_version}]}.tar gi_offline cloudctl-linux-amd64.tar.gz
cd /opt/registry
tar -rf ${air_dir}/gi_registry-${gi_versions[${gi_version}]}.tar data
cd $GI_TEMP
rm -rf /opt/registry
podman rm bastion-registry
podman rmi --all
rm -rf $GI_TEMP
echo "GI ${gi_versions[${gi_version}]} files prepared - copy $air_dir/gi_registry-${gi_versions[${gi_version}]}.tar to air-gapped bastion machine"
