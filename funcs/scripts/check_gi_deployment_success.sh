if [[ $(oc get rs -n $1 | grep cp-serviceability | wc -l) -eq 2 ]]
then
        oc delete rs -n $1 $(oc get rs -n $1 | grep cp-serviceability | awk '{print $1}')
fi
[[ $(oc get guardiuminsights -n $1 -o json|jq .items[0].status.versions.reconciled|tr -d '"') == "$2" ]] && echo 1 || echo 0
