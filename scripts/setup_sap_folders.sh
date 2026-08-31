#!/bin/bash

# ==============================================================================
# Script: setup_sap_folders.sh
# Descripción: Crea directorios para interfaces SAP en servidores remotos
#              y configura la limpieza anual mediante cron con 'find'.
# ==============================================================================

# --- Lista de Servidores SAP ---
SERVIDORES=(
#    "SAPSPA01"
#    "SAPSPB01"
#    "SAPSPP01"
#    "SAPSPE"
#    "SPEAS01"
#    "SPEAS02"
#    "SPEAS03"
#    "SPEAS04"
#    "SPEAS05"
    "SPEAS06"
)

# --- Variables de Rutas y Cron ---
BASE_DIR="/INTERFACES/FPHS/IN/FACTURACIO"
CRON_JOB="0 5 1 1 * /usr/bin/find ${BASE_DIR}/OK/ -type f -exec rm -f {} + >/dev/null 2>&1"

echo "=== Iniciando configuración en servidores SAP ==="

for server in "${SERVIDORES[@]}"; do
    echo "--------------------------------------------------"
    echo "Procesando servidor: $server"

    # 1. Verificación rápida de conectividad
    ping -c 1 -W 1 "$server" &> /dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] El servidor $server no responde a ping. Saltando..."
        continue
    fi

    # 2. Ejecución remota usando 'ssh -n' para no congelar el bucle
    ssh -n -o StrictHostKeyChecking=no root@"$server" "
        echo ' -> Creando estructura de directorios...';
        mkdir -p ${BASE_DIR}/OK ${BASE_DIR}/KO ${BASE_DIR}/LOGS;

        echo ' -> Configurando tarea cron anual...';
        ( crontab -l 2>/dev/null | grep -Fv '${BASE_DIR}/OK/' ; echo '${CRON_JOB}' ) | crontab -;
    "

    if [ $? -eq 0 ]; then
        echo "[OK] Configuración completada en $server."
    else
        echo "[ERROR] Fallo al ejecutar en $server."
    fi
done

echo "=================================================="
echo "=== Proceso finalizado ==="
