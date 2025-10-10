#!/bin/bash

# ==============================================================================
# Script para PREPARAR y REGISTRAR un cliente en SUSE Manager
#
# USO: sudo ./registrar_cliente.sh <nombre_del_script_bootstrap.sh>
# EJEMPLO: sudo ./registrar_cliente.sh sle124-prod.sh
#
# Este script debe ejecutarse DIRECTAMENTE EN LA MÁQUINA CLIENTE como root.
#
# Realiza dos fases:
# 1. PREPARACIÓN: Limpia la configuración local del cliente.
# 2. REGISTRO: Descarga y ejecuta el script de bootstrap desde SUSE Manager.
# ==============================================================================

# --- Variables y Comprobaciones ---
BOOTSTRAP_SCRIPT_NAME=$1
SUSE_MANAGER_HOST="susemanager01.santpau.es" # Cambia esto si es necesario

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Este script debe ser ejecutado como 'root' o con 'sudo'."
   exit 1
fi

if [ -z "$BOOTSTRAP_SCRIPT_NAME" ]; then
    echo "ERROR: No se ha especificado el nombre del script de bootstrap."
    echo "USO: $0 <nombre_del_script_bootstrap.sh>"
    exit 1
fi

# --- Fase 1: Preparación del Cliente ---
echo ""
echo "==================================================================="
echo " FASE 1: Preparando el sistema local..."
echo "==================================================================="

echo "[PASO 1/5] Moviendo repositorios de /etc/zypp/repos.d/ a .old ..."
mkdir -p /etc/zypp/repos.d.old
mv /etc/zypp/repos.d/* /etc/zypp/repos.d.old/ 2>/dev/null
echo "Hecho."

echo "[PASO 2/5] Desactivando repositorios en /etc/zypp/services.d/ ..."
if [ -d /etc/zypp/services.d ]; then
    sed -i 's/^\s*enabled\s*=\s*1/enabled = 0/g' /etc/zypp/services.d/*
    echo "Servicios desactivados."
else
    echo "El directorio /etc/zypp/services.d no existe. Omitiendo."
fi
zypper --non-interactive verify >/dev/null
echo "Hecho."

echo "[PASO 3/5] Des-registrando el sistema del SUSE Customer Center (SCC) ..."
SUSEConnect --cleanup
echo "Hecho."

echo "[PASO 4/5] Regenerando los IDs de la máquina virtual ..."
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id
dbus-uuidgen --ensure
systemd-machine-id-setup
echo "IDs regenerados."

echo "[PASO 5/5] Limpiando la configuración del Salt Minion ..."
systemctl stop salt-minion
rm -rf /etc/salt/pki/minion
rm -rf /var/cache/salt
echo "Hecho."

echo "✅ PREPARACIÓN LOCAL COMPLETADA."

# --- Fase 2: Registro en SUSE Manager (Método Pull) ---
echo ""
echo "==================================================================="
echo " FASE 2: Registrando en SUSE Manager..."
echo "==================================================================="

BOOTSTRAP_URL="http://${SUSE_MANAGER_HOST}/pub/bootstrap/${BOOTSTRAP_SCRIPT_NAME}"

echo "Descargando y ejecutando el script desde: $BOOTSTRAP_URL"
curl -Sks "$BOOTSTRAP_URL" | bash

if [ $? -eq 0 ]; then
    echo ""
    echo "----------------------------------------------------------"
    echo "✅ REGISTRO COMPLETADO"
    echo "El sistema debería aparecer en SUSE Manager en breve."
    echo "----------------------------------------------------------"
else
    echo "ERROR: El script de registro falló. Revisa la salida para más detalles."
    exit 1
fi

exit 0
