db2_inst_completed=false
db2_inst_phase_initiated=false
while ! $db2_inst_completed
do
        while ! $db2_inst_phase_initiated
        do
                if [[ `oc get pods|grep db2-instdb | wc -l` -ne 0 ]]
                then
                        db2_inst_phase_initiated=true
                fi
                sleep 30
        done
        if [[ `oc get pods|grep db2-instdb |grep OOMKilled|wc -l` -ne 0 ]]
        then
		for pod in `oc get pod --field-selector=status.phase==Failed|grep OOMKilled|awk '{print $1}'`
		do
			oc delete pod $pod
		done
        fi
        if [[ `oc get pod --field-selector=status.phase==Succeeded|grep db2-instdb|wc -l` -eq 1 ]]
        then
                db2_inst_completed=true
        fi
        sleep 10
done

