if [[ `oc get nodes --no-headers | awk '{print $2}'| grep -v '^Ready$'|wc -l` -eq 0 ]]
then
	nodes_ok="yes"
else
	nodes_ok="no"
fi
if [[ $nodes_ok == "yes" && `oc get co --kubeconfig=../ocp/auth/kubeconfig --no-headers|awk '{ print $3$4$5 }'|grep -v TrueFalseFalse|wc -l` -eq 0 ]]
then
	echo "0"
else
	echo "1"
fi
