#!/bin/bash

NAMESPACE="commvault-backup kafka"

echo "================================================================="
echo "📊 RADIOGRAFÍA DE BACKUPS (KAIROS02) - $(date)"
echo "================================================================="

echo -e "\n[1] REVISANDO PODS DE WORKERS (Debería estar vacío o mostrar jobs muy recientes):"
oc get pods -A

echo -e "\n[2] REVISANDO PVs TEMPORALES (Debería estar vacío o coincidir con jobs activos):"
oc get pv | grep 'Released'

echo -e "\n[2] REVISANDO PVCs TEMPORALES (Debería estar vacío o coincidir con jobs activos):"
oc get pvc -A

echo -e "\n[3] REVISANDO VOLUMESNAPSHOTS LÓGICOS:"
echo "(Ojo a la columna 'READYTOUSE'. Si dice 'false', el snapshot está corrupto o huérfano)"
oc get volumesnapshot -A

echo -e "\n[4] REVISANDO VOLUMESNAPSHOTCONTENTS FÍSICOS:"
echo "(Buscamos objetos atascados con política 'Retain' asociados a este namespace)"
oc get volumesnapshotcontent | grep -i $NAMESPACE

echo -e "\n[5] REVISANDO VOLUMEATTACHMENTS (El semáforo del CSI):"
echo "(Mostrando solo las primeras 15 líneas para no saturar. Buscamos 'ATTACHED: false' o edades anormales)"
oc get volumeattachments --sort-by=.metadata.creationTimestamp | head -n 16

echo -e "\n================================================================="
echo "✅ Escaneo completado. Por favor, comparte la salida para analizar."
echo "================================================================="
