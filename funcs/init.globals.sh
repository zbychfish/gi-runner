# Default settings
GI_HOME=`pwd` # gi-runner home directory
GI_TEMP=$GI_HOME/gitemp # temp directory
variables_file=$GI_HOME/variables.sh # variables file
declare -a fedora_supp_releases=(38) # list supported Fedora releases
declare -a gi_versions=(3.2.11 3.2.12 3.2.13)
declare -a gi_cases=(2.2.11 2.2.12 2.2.13)
declare -a gi_redis_releases=(1.6.5 1.6.5 1.6.5)
declare -a ics_versions=(3.19.18 3.19.19)
declare -a ics_cases=(1.15.18 1.15.19)
declare -a bundled_in_gi_ics_versions=(0 0 1)
declare -a ocp_versions=(0 1)
declare -a ocp_major_versions=(4.12 4.14)
declare -a ocp_supported_by_gi=(0 0 0)
declare -a ocp_supported_by_ics=(0 0)
declare -a ocp_supported_by_cp4s=(0)
declare -a ocp_supported_by_edr=(0)
declare -a gi_sizes=(small medium demo)
cp4s_channel="1.10"

linux_soft=("tar" "ansible" "haproxy" "openldap" "perl" "podman-docker" "ipxe-bootimgs" "chrony" "dnsmasq" "unzip" "wget" "httpd-tools" "policycoreutils-python-utils" "python3-ldap" "openldap-servers" "openldap-clients" "pip" "skopeo" "nfs-utils" "openssl")
python_soft=("passlib" "dnspython" "beautifulsoup4" "argparse" "jmespath")
galaxy_soft=("community-general-${galaxy_community_general}" "ansible-utils-${galaxy_ansible_utils}" "community-crypto-${galaxy_community_crypto}" "containers-podman-${galaxy_containers_podman}" )
