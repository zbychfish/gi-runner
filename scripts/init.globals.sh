#Global variables
declare -a gi_versions=(3.0.0 3.0.1 3.0.2 3.1.0 3.1.2 3.1.3 3.1.4 3.1.5)
declare -a ics_versions=(3.7.4 3.8.1 3.9.1 3.10.0 3.11.0 3.12.1 3.13.0 3.14.2 3.15.1 3.16.3)
declare -a ics_cases=(ibm-cp-common-services-1.3.4.tgz ibm-cp-common-services-1.4.1.tgz ibm-cp-common-services-1.5.1.tgz ibm-cp-common-services-1.6.0.tgz ibm-cp-common-services-1.7.0.tgz ibm-cp-common-services-1.8.1.tgz ibm-cp-common-services-1.9.0.tgz ibm-cp-common-services-1.10.2.tgz ibm-cp-common-services-1.11.1.tgz ibm-cp-common-services-1.12.3.tgz)
declare -a gi_cases=(ibm-guardium-insights-2.0.0.tgz ibm-guardium-insights-2.0.1.tgz ibm-guardium-insights-2.0.2.tgz ibm-guardium-insights-2.1.0.tgz ibm-guardium-insights-2.1.2.tgz ibm-guardium-insights-2.1.3.tgz ibm-guardium-insights-2.1.4.tgz ibm-guardium-insights-2.1.5.tgz)
declare -a bundled_in_gi_ics_versions=(0 2 3 7 7 7 7 7)
declare -a ocp_versions=(0 1 2 3 4)
declare -a ocp_major_versions=(4.6 4.7 4.8 4.9 4.10)
declare -a ocp_supported_by_gi=(0 0:1 0:1 0:1:2 0:1:2 0:1:2 0:1:2 0:1:2)
declare -a ocp_supported_by_ics=(0:1 0:1 0:1:2 0:1:2 0:1:2 0:1:2:3 0:1:2:3 0:1:2:3 0:1:2:3 0:1:2:3)
declare -a gi_sizes=(values-dev values-small)
fedora_supp_releases="34, 35"
rook_version="v1.8.2"
galaxy_community_general="4.7.0"
GI_HOME=`pwd`
GI_TEMP=$GI_HOME/gi-temp
file=$GI_HOME/variables.sh

