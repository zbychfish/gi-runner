echo "Remove ceph pools"
for pool in $(oc get cephblockpool -n rook-ceph -o name)
do
        oc delete -n rook-ceph $pool
done
echo "Remove storage classes"
for sc in $(oc get sc -o name|grep rook)
do
        oc delete $sc
done
echo "Remove ceph filesystems"
for fs in $(oc get CephFilesystems -n rook-ceph -o name)
do
        oc delete -n rook-ceph $fs
done
if [[ `oc get cephcluster -n rook-ceph -o name|wc -l` -ne 0 ]]
then
        echo "Accept data destruction"
        oc -n rook-ceph patch cephcluster rook-ceph --type merge -p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data"}}}'
        echo "Remove Ceph cluster"
        oc delete cephcluster rook-ceph -n rook-ceph
fi
echo "Remove Rook operator"
oc delete -f gi-temp/rook-latest-operator.yaml
#for op in $(oc get deployments -n rook-ceph -o name | grep rook)
#do
#        oc delete -n rook-ceph $op
#done
#echo "Wait for deployment cleanup"
#while [[ `oc get pods -n rook-ceph --no-headers|grep -v Completed|wc -l` -ne 0 ]]
#do
#        sleep 2
#done
#echo "Delete Security Context"
#for op in $(oc get SecurityContextConstraints -o name|grep rook)
#do
#        oc delete -n rook-ceph $op
#done
echo "Delete common objects"
oc delete -f scripts/rook-latest-common.yaml --ignore-not-found
echo "Delete crds objects"
oc delete -f scripts/rook-latest-crds.yaml --ignore-not-found
echo "rook-ceph has been uninstalled"

