<B>OpenShift Cluster, IBM Common Services and Guardium Insights installation automation on bare metal</B>
<HR>
<P>Automates OCP installation for releases: 4.6, 4.7, 4.8, 4.9
<P>Automates ICS installation for releases: 3.7.4, 3.8.1, 3.9.1, 3.10.0, 3.11.0, 3.12.1, 3.13.0, 3.14.1
<P>Automates GI installation for releases: 3.0.0, 3.0.1, 3.0.2, 3.1.0
<P>Supports installation with direct access to the Internet, using proxy and air-gapped (restricted) approach
<P>Implemented OCP architectures:
<LI>3 masters and 3+n workers with OCS or rook-ceph
<LI>3 masters only with OCS or rook-ceph
<LI>3 masters and 3+n workers and OCS tainted on 3 additional infra nodes
<LI>Bastion setup requires Fedora 34 or 35 as a operating system
<LI>GI 3.1 installation in air-gapped environment fails because of vendor decision to provide installation with CASE file in next release (log4shell issue).<BR>
Still installation in air-gapped is possible. In this case before execution a playbook 04 you must extract to mirrored registry the archive of ICS 3.14.1 (prepared before with prepare-ics.sh script)<BR>
tar -C /opt/registry -xvf <archives_dir>/ics_registry-3.14.11 data/*
<HR>
Examples of use at this link: <A href=https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/>https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/</A>
<HR>
Release description:
<P>v0.6.0
<LI>added support for patches related to log4j2 vulnerabilities (support CPFS 3.14.2, GI 3.1.2)
<LI>added playbooks to safely stop and start GI instance
<LI>ICS uninstallation playbook modified to cover complex uninstallation cases
<LI>Solved problem with reference to device name instead logical name on bastion in playbook 2
<LI>Solved problem with an occasional appearance of error during insertion secret for htpasswd authentication in OCP
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
<LI>playbook/21-shutdown-gi.yaml - Ansible playbook to shutdown GI instance for administration purposes on CPFS and OCP level
<LI>playbook/22-start-gi.yaml - Ansible playbook to start GI instance after shutdown with playbook 21
<LI>variables.sh - shell script with OCP environment variables, should loaded after login to bastion (. variables.sh)
<LI>prepare-scripts/prepare-air-gap-os-files.sh - script to gather software and OS packaged to setup bastion in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-coreos.sh - script to gather OCP installation tools and container images to install OCP in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-olm.sh - script to gather OLM catalogs and selected operator images to install OCP in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-rook.sh - script to gather Rook-Ceph images to install Rook in the air-gapped environment
<LI>prepare-scripts/prepare-air-gap-ics.sh - script to gather ICS images to install ICS in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-gi.sh - script to gather GI images to install GI in air-gapped environment
<LI>prepare-scripts/prepare-air-gap-additions.sh - script to gather additional images to install some services on OCP (for instance: openldap)
<LI>scripts/login_to_ocp.sh - logs admin to OCP cluster with new token
<HR>
Releases history:
<P>v0.5.2
<LI>Bug with parsing comma separated value of db2 nodes, ldap domain and ldap user list solved
<LI>GI deployment modified to reflect correct distribution of nodes
<P>v0.5.1
<LI>Solved problem with git branch conflict
<P>v0.5
<LI>added support for Guardium Insights 3.1
<LI>added init.sh variable to enable STAP direct streaming (available for GI 3.1+ installations) GI_STAP_STREAMING
<LI>added support OpenLDAP as application worked on OCP cluster, additional init.sh variable introduced GI_LDAP_DEPLOYMENT
<LI>added optional replacement OCP ingress certificate, 4 additional init.sh variables: GI_OCP_IN, GI_OCP_IN_CA, GI_OCP_IN_CERT, GI_OCP_IN_KEY
<LI>added optional replacement CPFS (ICS) endpoint certificate, 4 additional init.sh variables: GI_ICS_IN, GI_ICS_IN_CA, GI_ICS_IN_CERT, GI_ICS_IN_KEY
<LI>added optional replacement GI endpoint certificate, 4 additional init.sh variables: GI_IN, GI_IN_CA, GI_IN_CERT, GI_IN_KEY
<LI>modified rook-ceph deployment for air-gapped environment to use imagecontentsourcepolicy (requires rook registry archive rebuilding), update rook-ceph operator to version 1.7.8
<LI>Tested support Fedora35 as bastion
<P>v0.4
<LI> init.sh changed to provide simpler decision model for installation flow - all archives for air-gapped installation MUST be rebuild
<LI> added support for OCP 4.8 and 4.9
<LI> added support for ICS 3.11.0, 3.12.1, 3.13.0
<LI> added playbooks for deinstallation of GI and ICS
<LI> README.md finally updated
