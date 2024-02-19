# Default settings
GI_HOME=`pwd` # gi-runner home directory
GI_TEMP=$GI_HOME/gitemp # temp directory
variables_file=$GI_HOME/variables.sh # variables file

declare -a fedora_supp_releases=(38 39) # list supported Fedora releases
declare -a gi_versions=(3.2.13 3.3.0) # https://github.com/IBM/cloud-pak/blob/master/repo/case/ibm-guardium-insights/index.yaml
declare -a gi_cases=(2.2.13 2.3.0)
declare -a gi_redis_releases=(1.6.5 1.6.5)
declare -a ics_versions=(3.19.18 3.19.19 3.19.20) # https://github.com/IBM/cloud-pak/blob/master/repo/case/ibm-cp-common-services/index.yaml
declare -a ics_cases=(1.15.18 1.15.19 1.15.20)
declare -a bundled_in_gi_ics_versions=(1 2)
declare -a ocp_versions=(0 1)
declare -a ocp_major_versions=(4.12 4.14)
declare -a ocp_supported_by_gi=(0 0)
declare -a ocp_supported_by_ics=(0:1 0:1 0:1)
declare -a ocp_supported_by_cp4s=(0)
declare -a ocp_supported_by_edr=(0)
declare -a gi_sizes=(small medium demo)

gi_case_name="ibm-guardium-insights"
gi_case_inventory_setup="install"

cpfs_operator_namespace="common-service"
cpfs_case_name="ibm-cp-common-services"
cpfs_case_inventory_setup="ibmCommonServiceOperatorSetup"
cpfs_update_channel="3"

galaxy_community_general="8.2.0" # https://github.com/ansible-collections/community.general
galaxy_ansible_utils="3.0.0" # https://github.com/ansible-collections/ansible.utils
galaxy_community_crypto="2.17.0" # https://github.com/ansible-collections/community.crypto
galaxy_containers_podman="1.11.0" # https://github.com/containers/ansible-podman-collections

linux_soft=("tar" "ansible" "haproxy" "openldap" "perl" "podman-docker" "ipxe-bootimgs" "chrony" "dnsmasq" "unzip" "wget" "httpd-tools" "policycoreutils-python-utils" "python3-ldap" "openldap-servers" "openldap-clients" "python3-pip" "skopeo" "nfs-utils" "openssl")
python_soft=("passlib" "dnspython" "beautifulsoup4" "argparse" "jmespath" "requests")
galaxy_soft=("community-general-${galaxy_community_general}" "ansible-utils-${galaxy_ansible_utils}" "community-crypto-${galaxy_community_crypto}" "containers-podman-${galaxy_containers_podman}" )

matchbox_version=0.10.0 # https://github.com/poseidon/matchbox
ibm_pak_version=1.12.0 # https://github.com/IBM/ibm-pak

rook_operator_version="1.12.11" # https://github.com/rook/rook
rook_ceph_version="17.2.6"

nfs_provisioner_version=4.0.2 # https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner; tag does not correspond image 4.0.18 refers to image 4.0.2

px_channel="stable"
px_version="3.1.0"

cp4s_channel="1.10"
cp4s_versions=("1.10.18") # https://github.com/IBM/cloud-pak/blob/master/repo/case/ibm-cp-security/index.yaml
cp4s_cases=("1.0.43")
cp4s_case_name="ibm-cp-security"
cp4s_case_inventory_setup="ibmSecurityOperatorSetup"

edr_case_name="ibm-security-edr"
edr_cases=("1.0.1") # https://github.com/IBM/cloud-pak/blob/master/repo/case/ibm-security-edr/index.yaml
edr_case_inventory_setup="ibmSecurityEdrOperatorSetup"
