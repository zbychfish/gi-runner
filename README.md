<B>OpenShift Cluster, IBM Common Services and Guardium Insights installation automation on bare metal</B>
<HR>
<P>Automates OCP installation for releases: 4.6, 4.7, 4.8, 4.9
<P>Automates ICS installation for releases: 3.7.4, 3.8.1, 3.9.1, 3.10.0, 3.11.0, 3.12.1, 3.13.0
<P>Automates GI installation for releases: 3.0.0, 3.0.1, 3.0.2, 3.1.0
<P>Supports installation with direct access to the Internet, using proxy and air-gapped (restricted) approach
<P>Implemented OCP architectures:
<LI>3 masters and 3+n workers with OCS or rook-ceph
<LI>3 masters only with OCS or rook-ceph
<LI>3 masters and 3+n workers and OCS tainted on 3 additional infra nodes
<LI>Bastion setup requires Fedora 34 or 35 as a operating system
<HR>
Examples of use at this link: <A href=https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/>https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/</A>
<HR>
Releases:
<P>v0.5
<LI>added support for Guardium Insights 3.1
<LI>additional init.sh variable to enable STAP direct streaming (available for GI 3.1+ installations) GI_STAP_STREAMING
<LI>added support OpenLDAP as application worked on OCP cluster, additional init.sh variable introduced GI_LDAP_DEPLOYMENT
<LI>added optional replacement OCP ingress certificate, 4 additional init.sh variables: GI_OCP_IN, GI_OCP_IN_CA, GI_OCP_IN_CERT, GI_OCP_IN_KEY
<LI>added optional replacement CPFS (ICS) endpoint certificate, 4 additional init.sh variables: GI_ICS_IN, GI_ICS_IN_CA, GI_ICS_IN_CERT, GI_ICS_IN_KEY
<LI>Tested support Fedora35 as bastion
<HR>
Files:
<LI>init.sh - configures installation parameters
<LI>playbook/01-finalize-bastion-setup.yaml - Ansible playbook to configure bastion with Fedora OS onboard (will restart bastion in case of kernel update)
<LI>playbook/02-setup-bastion-for-ocp-installation.yaml - Ansible playbook to setup bastion to boot OCP cluster
<LI>playbook/03-finish_ocp_install.yaml - Ansible playbook to finalize OCP installation and setup cluster storage (OCS or rook-ceph)
<LI>playbook/04-install-ics.yaml - Ansible playbook to install IBM Common Services
<LI>playbook/05-install-gi.yaml - Ansible playbook to install Guardium Insights
<LI>playbook/50-set_configure_ldap.yaml - Ansible playbook to setup on bastion OpenLDAP instance
<LI>playbook/14-uninstall-ics.yaml - Ansible playbook to uninstall ICS
<LI>playbook/15-uninstall-gi.yaml - Ansible playbook to uninstall GI
<LI>variables.sh - shell script with OCP environment variables, should loaded after login to bastion (. variables.sh)
<LI>prepare-scripts/prepare-air-gap-os-files.sh - script to gather software and OS packaged to setup bastion in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-coreos.sh - script to gather OCP installation tools and container images to install OCP in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-olm.sh - script to gather OLM catalogs and selected operator images to install OCP in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-rook.sh - script to gather Rook-Ceph images to install Rook in the air-gapped environment
<LI>prepare-scripts/prepare-air-gap-ics.sh - script to gather ICS images to install ICS in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-gi.sh - script to gather GI images to install GI in air-gapped environment
<LI>scripts/login_to_ocp.sh - logs admin to OCP cluster with new token
<HR>
Releases history:
<P>v0.4
<LI> init.sh changed to provide simpler decision model for installation flow - all archives for air-gapped installation MUST be rebuild
<LI> added support for OCP 4.8 and 4.9
<LI> added support for ICS 3.11.0, 3.12.1, 3.13.0
<LI> added playbooks for deinstallation of GI and ICS
<LI> README.md finally updated
