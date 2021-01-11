if [[ `oc get csr -o name | wc -l` -ne "0" ]]
then
	if [[ `oc get csr --no-headers -o custom-columns=CONDITION:.status.conditions[0].type | grep -v Approved | wc -l` -ne "0" ]]
      	then
      		oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
      	fi
fi
if [[ `oc get nodes --no-headers | awk '{print $2}'| grep -v '^Ready$'|wc -l` -eq 0 ]]
then
	echo `oc get nodes --no-headers | wc -l`
else
	echo "0"
fi
