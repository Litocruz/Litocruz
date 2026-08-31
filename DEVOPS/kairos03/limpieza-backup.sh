# Buscamos PVs que estén en Released y limpiamos sus attachments
#for pv in $(oc get pv | grep Released | awk '{print $1}'); do
#    va_name=$(oc get volumeattachments -o json | jq -r --arg pv "$pv" '.items[] | select(.spec.source.persistentVolumeName==$pv) | .metadata.name')
#    if [ ! -z "$va_name" ]; then
#        echo "Limpiando conexión para PV en Released: $pv ($va_name)"
#        #oc patch volumeattachment $va_name --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
#        #oc delete volumeattachment $va_name --cascade=orphan
#    fi
#done

for va in $(oc get volumeattachments -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
    PV_NAME=$(oc get volumeattachment $va -o jsonpath='{.spec.source.persistentVolumeName}')
    if [ ! -z "$PV_NAME" ] && ! oc get pv $PV_NAME > /dev/null 2>&1; then
        echo "Limpiando attachment huérfano: $va"
        oc patch volumeattachment $va --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
        oc delete volumeattachment $va --cascade=orphan --wait=false
    fi
done
