
<B>OpenShift Cluster installation automation on bare metal</B>
<HR>
Implemented OCP architectures:
<LI>Air-gap installation for 3 masters and 3+n workers with OCS 4.6
<LI>Air-gap installation for 3 masters only with OCS 4.6
<LI>Air-gap installation for 3 masters and 3+n workers and OCS 4.6 tainted on 3 additional infra nodes
<LI>Air-gap installation on one node only with open source rook-ceph 1.1.7 (not supported OCP architecture for production)
<HR>
OCP installation with direct access to the internet
  <LI> Clone gi-runner to your bastion. Automation tested on CentOS 8.3.x and CentOS Streams 8. Should work without problem on RedHat 8, other Linux distribution require some modifications
  <LI> Prepare your OCP cluster nodes templates (check section OCP nodes)
  <LI> Execute init.sh script
    
