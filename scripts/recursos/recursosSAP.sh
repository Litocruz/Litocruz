#!/bin/bash
# Reporte de Salud SAP - Versión Auto-Detect
# Autor: Gemini para Julián (Logicalis)

# 1. Auto-detección del SID (3 caracteres en mayúsculas)
SID=$(ls /usr/sap | grep -E '^[A-Z0-9]{3}$' | head -n 1)

# 2. Auto-detección de la instancia (Carpeta que empieza por J o D + 2 números)
# Buscamos dentro de /usr/sap/SID/
INSTANCE_DIR=$(ls /usr/sap/$SID 2>/dev/null | grep -E '^[JD][0-9]{2}$' | head -n 1)

# Si no encuentra carpeta J o D, probamos con la carpeta de perfiles
if [ -z "$INSTANCE_DIR" ]; then
    INSTANCE_DIR=$(ls /usr/sap/$SID/SYS/profile/ 2>/dev/null | grep -E '_[JD][0-9]{2}_' | cut -d'_' -f2 | head -n 1)
fi

INSTANCE=${INSTANCE_DIR:1:2}
LOG_DIR="/usr/sap/$SID/$INSTANCE_DIR/work"

echo "========================================================="
echo " EVIDENCIAS: $HOSTNAME | SID: $SID | INST: $INSTANCE"
echo "========================================================="

if [ -z "$SID" ]; then
    echo "ERROR: No se detectó un SID válido en /usr/sap"
    #exit 1
fi

echo -e "\n[1] RECURSOS DE SISTEMA (CPU cores: $(nproc))"
uptime
echo "Proceso con más consumo de CPU:"
ps -eo pcpu,pid,user,comm --sort=-pcpu | grep -vE "grep|ps" | head -n 2

echo -e "\n[2] MEMORIA Y SWAP"
free -mh
echo -e "\n[3] PROCESOS SAP"
/usr/sap/hostctrl/exe/sapcontrol -prot NI_HTTP -nr $INSTANCE -function GetProcessList

echo -e "\n[4] LOGS DE ERROR (std_server*.out)"
if [ -d "$LOG_DIR" ]; then
    grep -iE "OutOfMemoryError|shutting down with exit code" $LOG_DIR/std_server*.out | tail -n 10
else
    echo "LOG_DIR no encontrado: $LOG_DIR"
fi

echo -e "\n========================================================="
