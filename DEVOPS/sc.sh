# Obtener todos los VolumeAttachments que tengan una "d" en su columna AGE
viejos=$(oc get volumeattachments --no-headers | awk '$6 ~ /d/ {print $1}')

for va in $viejos; do
    echo "Procesando: $va"
    # Quitamos el finalizer para forzar el borrado
    oc patch volumeattachment $va -p '{"metadata":{"finalizers":null}}' --type=merge
    # Borramos el objeto
    oc delete volumeattachment $va --cascade=orphan
done
