<B>Cloud Pak's installation automation tool on bare metal</B>
<HR>
<P>Automates OCP installation for releases: 4.12, 4.14
<P>Automates CPFS installation for releases: 3.19.18, 3.19.19, 3.19.20, 3.23.12
<P>Automates GI installation for releases: 3.2.13, 3.3.0, 3.3.1
<P>Automates CP4S installation for 1.10 channel
<P>Automates EDR installation ifor release 1.0.2 (online installation only because of bug in the images list)
<P>Supports installation with direct access to the Internet, using proxy or air-gapped (restricted) approach
<P>Supported storage backends: rook-ceph, ODF, Portworx Essentials (only online installation)
<P>Implemented OCP architectures:
<LI>3 masters and 3+n workers
<LI>3 masters only
<LI>Bastion setup requires Fedora 38 or 39 as a operating system
<HR>
Examples of use at this link: <A href=https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/>https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/</A>
<HR>
This tool installs everything from scratch. It does not support installation CPFS or GI on preinstalled OCP.
<HR>
For online installation execute init.sh script to collect installation parameteres. Then shell variables defined in variables.sh file control Ansible playbook - plays/install.yaml to deploy all desired solutions.
<HR>
For offline installation you need collect installation tools and container images and then deliver them to bastion located in the restricted network.
All archives for air-gapped installation are now managed by one script - prepare_offline.sh
prepare_offline.sh accepts parameter for skip some prepared before archives:
<UL>
<LI>1 - skips phase to gather OS, Python and Ansible packages
<LI>2 - skips phase 1 and OCP archives preparation
<LI>3 - skips 1, 2 and rook archives preparation
<LI>4 - skips 1, 2, 3 and collection openldap and nfs-client images, move to task to collect Cloud Pak's image
</UL>
<HR>
init.sh script supports parameter skip_offline - it skip archives extraction and bastion offline preparation in case of restart the init.sh for air-gapped installation (avoid to untar GB's of data again)
<HR>
The play install.yaml accepts skip_phase  parameter, must be specified with -e flag (like ansible-playbook plays/install -e skip_phase=<phase>):
<UL>
skip_phase allows restart install.yaml play from defined point (to avoid full restart of deployment), possible values:
<LI>1 ignores bastion setup preparation, play waiting for OCP bootstrap phase finish
<LI>2 moves to storage deployment, OCP must be deployed fully
<LI>3 moves to image registry setup, assumes that storage option is correctly deployed
<LI>4 moves to CPFS deployment
<LI>5 moves to openldap deployment, assumes that CPFS has been installed (GI and standalone CPFS deployment)
<LI>6 moves to nfs client deployment, assumes that CPFS and openldap has been installed
<LI>7 moves to Cloud Pak deployment, all other phase must be finished with success
</UL>
<HR>
Release history:
<P>v0.12.0
<B>EDR support added</B>
<UL>New features and changes:
<LI>Supports GI 3.3.x
<LI>Supports air-gapped installation of CP4S
<LI>Supports EDR 1.0.2 (air-gapped installation option is built-in but is not working because of bug in the case file)
<LI>scripts and playbooks fully reviewed and simplified
<LI>all function put into funcs/functions.sh (alphabetical order)
<LI>all supporting scripts put into funcs/scripts
<LI>all static yamls put into funcs/yamls
<LI>all dynamic yamls will be created in gitemp/yamls
<LI>all ansible plays in plays directory
<LI>all ansible templates in plays/templates directory
</UL>
<HR>
<P>v0.11.2
<B>cloudctl tool not collected by GI prescript</B>
<HR>
<P>v0.11.1
<B>Lack conditions for non-airgap flow in stage2.yaml playbook</B>
<HR>
<P>v0.11.0
<B>Support new OCP, CPFS and GI releases</B>
<UL>New features and changes:
<LI>matchbox supports RHCOS booting in EFI mode in addition to BIOS
<LI>matchbox updated to 0.10.0
<LI>supported installations:
<UL>
<LI>Openshift - 4.10, 4.12, 4.14
<LI>CPFS - 3.19.18 and 3.19.19
<LI>Guardium Insights - 3.2.11, 3.2.12, 3.2.13
</UL>
<LI>Offline installation has modified script to gather software for bastion and now produces the unzip rpm stored separately. The reason is to install it on Fedora bastion where unzip tool is not preinstalled - to allow unzip gi-runner archive. Use command 'dnf -qy --disablerepo=* localinstall download/unzip*.rpm'
<LI>skip_phase flags for main ansible playbook
<UL>
<LI>1 - skips bastion preparation and continue from stage2
<LI>2 - skips all steps before storage setup
<LI>3 - skips all OCP installation steps and storage setup
<LI>4 - skips image registry setup
<LI>5 - skips CPFS installation
<LI>6 - skips NFS provisioner setup for GI
<LI>7 - skips GI deployment
<LI>8 - skips openldap deployment
</UL>
</UL>
<HR>
<P>v0.10.1
<LI>Bugs related to problem with air-gapped installation removed
Files:
<LI>init.sh - configures installation parameters
<LI>playbook/install_all.yaml - Ansible playbook to manage installation flow
<LI>Playbook install_all.yaml accept option -e "skip_phase=X", where X:
<UL>
<LI>1 - skips bastion preparation and continue from stage2
<LI>2 - skips all steps before storage setup on OCP
<LI>3 - skips all OCP installation steps and installs configured applications (ICS, GI/CP4S, LDAP)
<LI>4 - skips all OCP installation steps and ICS
<LI>5 - skips all OCP installation steps, ICS and GI/CP4S
<LI>6 - skips all OCP installation steps, ICS, GI/CP4S and LDAP
</UL>
<LI>playbook/uninstall-gi.yaml - Ansible playbook to uninstall GI
<LI>playbook/shutdown-gi.yaml - Ansible playbook to shutdown GI instance for administration purposes on CPFS and OCP level
<LI>playbook/start-gi.yaml - Ansible playbook to start GI instance after shutdown with playbook 21
<LI>variables.sh - shell script with OCP environment variables, should loaded after login to bastion (. variables.sh)
<LI>prepare-scripts/prepare-air-gap-os-files.sh - script to gather software and OS packaged to setup bastion in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-coreos.sh - script to gather OCP installation tools and container images to install OCP in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-olm.sh - script to gather OLM catalogs and selected operator images to install OCP in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-rook.sh - script to gather Rook-Ceph images to install Rook in the air-gapped environment
<LI>prepare-scripts/prepare-air-gap-ics.sh - script to gather ICS images to install ICS in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-gi.sh - script to gather GI images to install GI in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-additions.sh - script to gather additional images to install some services on OCP (for instance: openldap)
<LI>scripts/login_to_ocp.sh - logs admin to OCP cluster with new token
<LI>scripts/ics-uninstall.sh - native DEV team script to remove ICS instances
<HR>
<P>v0.10.0
<LI>Guardium Insights 3.2 support
<LI>Added support for ODF in case of OCP 4.9+
<LI>ICS 3.19 and 3.20 support
<LI>CP4S 1.10.x support (online installation only)
<LI>Added support Portworx Essentials as a storage backend (online installation only)
<LI>Added support for OVN CNI
<LI>Update rook-cepth to 1.9.9
<LI>Update matchbox to 0.9.1
<LI>Added activation STAP streaming and outliers Demo Mode in the installation process
<HR>
<P>v0.9.1
<LI>Resolved bug with ICS variables when only GI and ICS is installed
<HR>
<P>v0.9.0
<LI>added support of Fedora 36 as a bastion
<LI>playbook/16-uninstall-ldap.yaml - new playbook allows safely uninstall OpenLDAP instance
<LI>OpenLDAP users have now mail attribute set (support CP4S demands for LDAP users)
<LI>introduced installation support for Cloud Pack for Security (channel 1.9)
<UL>
<LI>only online installation implemented at this moment
<LI>ICS installed from CP4S operator inheritance
<LI>supports all standard CR installation options (application selection, storage class, backup PVC size)
</UL>
<LI>added support for GI 3.1.6, 3.1.7, ICS 3.18.0, Fedora 36 as a bastion
<LI>new playbook - upgrade-gi.yaml - for upgrade GI to the latest version, if you installed GI prior 3.1.6, you must before install additional galaxy package - "ansible-galaxy collection install ansible.utils"
<UL>
<LI>only online installations supported
<LI>only upgrade from 3.1.x to 3.1.y supported
<LI>possible upgrade of ICS by manual modification the variable GI_ICS_VERSION
</UL>
<HR>
<P>v0.8.0
<LI>Added installation support for GI 3.1.4 and 3.1.5, OCP 4.10.x, ICS 3.16.x and 3.17.x
<LI>Some bugs in air-gapped installation removed (tested installation OCP 4.8.35 with ICS 3.14.2 and GI 3.1.5 
<LI>prescripts use new function approach
<HR>
<P>v0.7.1
<LI>Hardcoded ens192 NIC interface reference in stage1 playbook removed
<LI>Rook-Ceph support for OCP 4.6 and 4.7 removed because the latest Ceph releases supports only OCP 4.8+
<LI>Incorrect reference to subdirectory in rook-uninstall.sh corrected
<HR>
<P>v0.7.0
<LI>Support GI 3.1.3 and ICS 3.15
<LI>init.sh modified to evaluate inputs and provides more readable output
<LI>Playbooks modified, only one playbook must be manually started, the others will be started automatically based on installation decisions
<LI>Playbook install_all.yaml accept option -e "skip_phase=X", where X:
<UL>
<LI>1 - skips bastion preparation and continue from stage2
<LI>2 - skips all steps before storage setup on OCP
<LI>3 - skips all OCP installation steps and installs configured applications (ICS, GI, LDAP)
<LI>4 - skips all OCP installation steps and ICS
<LI>5 - skips all OCP installation steps, ICS and GI
<LI>6 - skips all OCP installation steps, ICS, GI and LDAP
</UL>
<LI>Implemented installation flow to support multi-subnet location of OCP nodes. DHCP Relay must be set on routers and points the bastion.
<LI>Possible selection different ICS version than default for GI installation (except air-gapped approach)
<HR>
<P>v0.6.2
<LI>Solved bug with rook-ceph installation when nodes are not dedicated
<LI>Identified bug with OCS installation on cluster with more that 3 workers, in this case storage must be assigned to first 3 nodes - will be solved in next release
<HR>
<P>v0.6.1
<LI>Solved bug with requesting proxy parameters for non-proxy installations
<LI>Solved incorrect message for non-tainted DB2 installations
<HR>
<P>v0.6.0
<LI>added support for patches related to log4j2 vulnerabilities (support CPFS 3.14.2, GI 3.1.2)
<LI>added playbooks to safely stop and start GI instance
<LI>ICS uninstallation playbook modified to cover complex uninstallation cases
<LI>Added init.sh variables GI_META_STORAGE_SIZE, GI_ACTIVELOGS_STORAGE_SIZE, GI_MONGO_DATA_STORAGE_SIZE, GI_MONGO_METADATA_STORAGE_SIZE, GI_KAFKA_STORAGE_SIZE and GI_ZOOKEEPER_STORAGE_SIZE to override default sizes of PVC define in GI templates (all values refers to storage size in GB's)
<LI>Added init.sh variable GI_DB2_TAINTED to separate DB2 nodes from other GI services (OCP cluster must have 3 additional workers besides dedicated for DB2)
<LI>Added init.sh variables GI_ROOK_NODES, GI_ICS_NODES, GI_GI_NODES to install Rook-Ceph, ICS and GI on defined node list
<LI>init.sh rewritten to be more readable and provides evaluation of most inserted values
<LI>update rook-ceph operator to version 1.8.2 (rook images must be recreated for air-gapped installation)
<LI>Solved problem with GPG keys during OLM images mirror
<LI>Solved problem with reference to device name instead logical name on bastion in playbook 2
<LI>Solved problem with an occasional appearance of error during insertion secret for htpasswd authentication in OCP
<HR>
<P>v0.5.2
<LI>Bug with parsing comma separated value of db2 nodes, ldap domain and ldap user list solved
<LI>GI deployment modified to reflect correct distribution of nodes
<HR>
<P>v0.5.1
<LI>Solved problem with git branch conflict
<HR>
<P>v0.5
<LI>added support for Guardium Insights 3.1
<LI>added init.sh variable to enable STAP direct streaming (available for GI 3.1+ installations) GI_STAP_STREAMING
<LI>added support OpenLDAP as application worked on OCP cluster, additional init.sh variable introduced GI_LDAP_DEPLOYMENT
<LI>added optional replacement OCP ingress certificate, 4 additional init.sh variables: GI_OCP_IN, GI_OCP_IN_CA, GI_OCP_IN_CERT, GI_OCP_IN_KEY
<LI>added optional replacement CPFS (ICS) endpoint certificate, 4 additional init.sh variables: GI_ICS_IN, GI_ICS_IN_CA, GI_ICS_IN_CERT, GI_ICS_IN_KEY
<LI>added optional replacement GI endpoint certificate, 4 additional init.sh variables: GI_IN, GI_IN_CA, GI_IN_CERT, GI_IN_KEY
<LI>modified rook-ceph deployment for air-gapped environment to use imagecontentsourcepolicy (requires rook registry archive rebuilding), update rook-ceph operator to version 1.7.8
<LI>Tested support Fedora35 as bastion
<HR>
<P>v0.4
<LI> init.sh changed to provide simpler decision model for installation flow - all archives for air-gapped installation MUST be rebuild
<LI> added support for OCP 4.8 and 4.9
<LI> added support for ICS 3.11.0, 3.12.1, 3.13.0
<LI> added playbooks for deinstallation of GI and ICS
<LI> README.md finally updated
