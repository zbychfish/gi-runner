if [[ `oc get csr -o name | wc -l` -ne "0" ]]
then
	echo "OK"
fi

