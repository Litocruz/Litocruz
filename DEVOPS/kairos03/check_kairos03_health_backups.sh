#!/bin/bash
# ==============================================================================
# Verificador de Salud de Backups Commvault (Snapshots CSI) - Kairos
# ==============================================================================

# Configuración: Umbral de alerta en horas
THRESHOLD_HOURS=24
DATE_NOW=$(date +%s)

echo -e "🔎 Iniciando auditoría de Snapshots Commvault...\n"
echo -e "NAMESPACE\tSNAPSHOT_NAME\tSTATUS\tAGE (Hrs)\tPVC_SOURCE"
echo -e "---------\t-------------\t------\t---------\t----------"

# Obtenemos los VolumeSnapshots de todos los namespaces
oc get volumesnapshots -A -o json | jq -c '.items[]' | while read -r snap; do
    NS=$(echo "$snap" | jq -r '.metadata.namespace')
    NAME=$(echo "$snap" | jq -r '.metadata.name')
    READY=$(echo "$snap" | jq -r '.status.readyToUse // "false"')
    PVC=$(echo "$snap" | jq -r '.spec.source.persistentVolumeClaimName // "N/A"')
    CREATION=$(echo "$snap" | jq -r '.metadata.creationTimestamp')
    
    # Calcular antigüedad
    SNAP_TIME=$(date -d "$CREATION" +%s)
    DIFF_SECONDS=$((DATE_NOW - SNAP_TIME))
    DIFF_HOURS=$((DIFF_SECONDS / 3600))

    # Definir color y estado
    STATUS="✅ READY"
    if [ "$READY" != "true" ]; then
        STATUS="❌ FAILED"
    elif [ "$DIFF_HOURS" -gt "$THRESHOLD_HOURS" ]; then
        STATUS="⚠️ STALE"
    fi

    echo -e "$NS\t$NAME\t$STATUS\t$DIFF_HOURS\t$PVC"

done | column -t -s $'\t'

echo -e "\n--- REVISIÓN DE CONFIGURACIÓN ---"
# Verificar si el StorageClass de Commvault está presente
CV_SC=$(oc get storageclass | grep -i "commvault" | awk '{print $1}')
if [ -z "$CV_SC" ]; then
    echo "⚠️  Aviso: No se detecta una StorageClass explícita de Commvault."
else
    echo "✅ StorageClass detectada: $CV_SC"
fi

# Verificar VolumeSnapshotClasses (Las "recetas" del backup)
echo -e "\n--- VOLUME SNAPSHOT CLASSES ---"
oc get volumesnapshotclass -o custom-columns=NAME:.metadata.name,DRIVER:.driver,DELETION_POLICY:.deletionPolicy

echo -e "\n--- 🚮 BUSCANDO SNAPSHOTS HUÉRFANAS ---"
# Busca contenidos de snapshot que no tienen un objeto snapshot vinculado
oc get volumesnapshotcontents -o json | jq -r '.items[] | select(.spec.volumeSnapshotRef.uid == null) | .metadata.name' | while read orphan; do
    echo "🔴 Detectada snapshot huérfana en disco: $orphan"
done

echo -e "\n--- 📋 BUSCANDO ACTIVIDAD RECIENTE (Eventos) ---"
# Esto busca errores o éxitos en la creación de snapshots en las últimas horas
oc get events -A --field-selector type!=Normal | grep -iE "VolumeSnapshot|vsphere-csi" | tail -n 10 || echo "No se detectan errores recientes en CSI."

echo -e "\n--- 🤖 ESTADO DEL OPERADOR COMMVAULT ---"
# Verificamos si el pod que gestiona la comunicación está vivo
oc get pods -n commvault 2>/dev/null || echo "⚠️  No se encontró el namespace 'commvault'. ¿El backup es externo?"


echo -e "\n--- 💾 ESTADO DE PVCs (Persistent Volume Claims) ---"
echo -e "NAMESPACE\tPVC_NAME\tSTATUS\tVOLUME\tCAPACITY\tSTORAGECLASS"
echo -e "---------\t--------\t------\t------\t--------\t------------"

# Buscamos PVCs que no estén en estado 'Bound' (Los problemas reales)
oc get pvc -A -o json | jq -r '.items[] | select(.status.phase != "Bound") | [.metadata.namespace, .metadata.name, .status.phase, .spec.volumeName, .status.capacity.storage, .spec.storageClassName] | @tsv' | column -t -s $'\t'

# Si no hay PVCs problemáticos, informamos
if [ $(oc get pvc -A --no-headers | grep -v "Bound" | wc -l) -eq 0 ]; then
    echo "✅ Todos los PVCs están Bound (Vinculados correctamente)."
fi

echo -e "\n--- 🏗️ ESTADO DE PVs (Persistent Volumes) ---"
# Verificamos si hay volúmenes físicos fallidos
oc get pv -o json | jq -r '.items[] | select(.status.phase == "Failed" or .status.phase == "Released") | [.metadata.name, .status.phase, .spec.capacity.storage, .spec.claimRef.namespace] | @tsv' | column -t -s $'\t'

if [ $(oc get pv --no-headers | grep -E "Failed|Released" | wc -l) -eq 0 ]; then
    echo "✅ No hay volúmenes físicos (PV) en estado Failed o huérfanos."
fi


echo -e "\n--- 📉 RESUMEN DE DESPERDICIO ---"
TOTAL_WASTE=$(oc get pv | grep Released | awk '{print $2}' | sed 's/Gi//g; s/Mi/\/1024/g' | paste -sd+ - | bc)
echo "⚠️  Tienes aproximadamente ${TOTAL_WASTE} GiB bloqueados en estado Released."
