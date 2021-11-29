<B>OpenShift Cluster, IBM Common Services and Guardium Insights installation automation on bare metal</B>
<HR>
<P>Automates OCP installation for releases: 4.6, 4.7, 4.8, 4.9
<P>Automates ICS installation for releases: 3.7.4, 3.8.1, 3.9.1, 3.10.0, 3.11.0, 3.12.1, 3.13.0
<P>Automates GI installation for releases: 3.0.0, 3.0.1, 3.0.2
<P>Support installation with direct access to the Internet, using proxy and air-gapped (restricted) approach
<P>Implemented OCP architectures:
<LI>3 masters and 3+n workers with OCS or rook-ceph
<LI>3 masters only with OCS or rook-ceph
<LI>3 masters and 3+n workers and OCS tainted on 3 additional infra nodes
<HR>
Examples of use at this link: <A href=https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/>https://guardiumnotes.wordpress.com/2021/09/09/automation-of-openshift-and-guardium-insights-installation-on-bare-metal/</A>
<HR>
Releases:
<P>4.0 - main
<LI> init.sh changed to provide simpler decision model for installation flow - all archives for air-gapped installation MUST be rebuild
<LI> added support for OCP 4.8 and 4.9
<LI> added support for ICS 3.11.0, 3.12.1, 3.13.0
<LI> added playbooks for deinstallation of GI and ICS


