#Global variables
declare -a gi_versions=(3.0.0 3.0.1 3.0.2 3.1.0 3.1.2)
declare -a ics_versions=(3.7.4 3.8.1 3.9.1 3.10.0 3.11.0 3.12.1 3.13.0 3.14.2)
declare -a bundled_in_gi_ics_versions=(0 2 3 7 7)
declare -a ocp_versions=(0 1 2 3)
declare -a ocp_major_versions=(4.6 4.7 4.8 4.9)
declare -a ocp_supported_by_gi=(0 0:1 0:1 0:1:2 0:1:2)
declare -a ocp_supported_by_ics=(0:1 0:1 0:1:2 0:1:2 0:1:2 0:1:2:3 0:1:2:3 0:1:2:3)
declare -a gi_sizes=(values-dev values-small)
fedora_supp_releases="34, 35"
GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
file=$GI_HOME/variables.sh

