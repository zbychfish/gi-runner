<B>OpenShift Cluster installation automation on bare metal</B>
<HR>
Implemented OCP architectures:
<LI>Air-gap installation for 3 masters and 3+n workers with OCS 4.6
<LI>Air-gap installation for 3 masters only with OCS 4.6
<LI>Air-gap installation for 3 masters and 3+n workers and OCS 4.6 tainted on 3 additional infra nodes
<LI>Air-gap installation on one node only with open source rook-ceph 1.1.7 (not supported OCP architecture for production)
<HR>
OCP installation with direct access to the internet
<UL>
  <LI> Clone gi-runner to your bastion. Automation tested on CentOS 8.3.x and CentOS Streams 8. Should work without problem on RedHat 8, other Linux distribution require some modifications
  <LI> Prepare your OCP cluster nodes templates (check section OCP nodes)
  <LI> Execute init.sh script in the gi-runner home directory
    <UL>
      <LI> Insert OCP minor number, for instance 4.6.20 - "Insert OCP version to install:"
      <LI> Answer N for question about air-gap installation - "Is your environment air-gapped? (N)o/(Y)es:"
      <LI> Answer D for question about Direct or Proxy access to the intenet - "Has your environment direct access to the internet or use HTTP proxy? (D)irect/(P)roxy:"
<LI>Decide which NTP server should be used by OCP cluster, external (N) or installed on bastion (Y) - "Would you like setup NTP server on bastion? (Y)es/(N)o:"
 <LI>In case of external NTP server insert its IP address - "Insert NTP server IP address"
 <LI>Confirm the time zone on bastion (Y) or correct it (N) - "Your Timezone on bastion is set to America/New_York, is it correct one [Y/N]:"
 <LI>In case of NTP server installed on bastion confirm the time and date (Y) or correct it (N) - "Current local time is Tue Mar 23 18:25:17 CET 2021, is it correct one [Y/N]"
 <LI>Insert cluster domain, it should be dedicated domain like <cluster_domain>.<corporate_domain>. Domain will be managed on bastion - "Insert cluster domain (your private domain name), like ocp.io.priv:"
 <LI>Accept or reject one node OCP installation - "Is your installation the one node (allinone)? (Y)es/(N)o:"
<UL>
In case of multinode installation:
<li>Accept or reject 3 nodes OCP installation - "Is your installation the 3 nodes only (master only)? (Y)es/(N)o:"
<li>Provide second disk specification for OpenShift Container Storage (OCS) - "Provide cluster device specification for storage virtualization (for example sdb):"
<li>Provide size of disk attached to OCS nodes - "Provide maximum space on cluster devices for storage virtualization (for example 300) in GB:"
<ul>
For installation with separate workers:
<li>Decide if the DB2 database will be installed in HA cluster, only for Guardium Insights installation - "Would you like install DB2 in HA configuration (N)o/(Y)es?:"
<li>Specify separation of OCS workers from other, it installs OCS in taint, you need minimum 4 workers in this case - "Would you like isolate (taint) OCS nodes in the OCP cluster (N)o/(Y)es?:"
<li>Decide if the DB2 workers should be separated from other services, only for Guardium Insights installation - "Would you like isolate (taint) DB2 node/s in the OCP cluster (N)o/(Y)es?:"
</UL>
</UL>
<li>Provide bastion IP, in case of two or more interfaces it defines used for cluster management - "Insert Bastion IP used to communicate with your OCP cluster:"
  <LI> Execute init.sh script.
    <UL>
      <LI> Insert OCP minor number - for instance 4.6.20
      <LI> Answer N for question about air-gap inatllation
      <LI> Answer D for question about Direct or Proxy access to the intenet

    </UL>

</UL>

