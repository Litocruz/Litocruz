#!/bin/bash

# ==============================================================================
# Script ORQUESTADOR para registrar un cliente en SUSE Manager desde una
# terminal remota.
#
# USO: ./registrar_remoto.sh <usuario@cliente> <nombre_del_script_bootstrap.sh>
# EJEMPLO: ./registrar_remoto.sh root@intranet01.santpau.es sle124-prod.sh
#
# Este script se ejecuta desde TU MÁQUINA PERSONAL.
# Se conecta por SSH al cliente y ejecuta allí todo el proceso.
# ==============================================================================

# --- Comprobaciones Iniciales ---
CLIENT_SSH_TARGET=$1
BOOTSTRAP_SCRIPT_NAME=$2
SUSE_MANAGER_HOST="susemanager01.santpau.es" # Cambia esto si es necesario

if [ -z "$CLIENT_SSH_TARGET" ] || [ -z "$BOOTSTRAP_SCRIPT_NAME" ]; then
    echo "ERROR: Faltan argumentos."
    echo "USO: $0 <usuario@cliente> <nombre_del_script_bootstrap.sh>"
    exit 1
fi

echo "Iniciando proceso de registro para $CLIENT_SSH_TARGET..."
echo ""

# --- Ejecución Remota del Script Completo ---
# Se usa un "here document" (<< 'EOF') para pasar todo el script
# al cliente a través de SSH y ejecutarlo allí.
ssh -o StrictHostKeyChecking=no "$CLIENT_SSH_TARGET" "bash -s" -- "$BOOTSTRAP_SCRIPT_NAME" << 'REMOTE_SCRIPT_EOF'

#!/bin/bash
# --- Este es el script que se ejecutará en la máquina cliente ---

# --- Variables y Comprobaciones ---
BOOTSTRAP_SCRIPT_NAME_REMOTE=$1
SUSE_MANAGER_HOST_REMOTE="susemanager01.santpau.es"

if [[ $EUID -ne 0 ]]; then
   echo "ERROR (remoto): Este script debe ser ejecutado como 'root'."
   exit 1
fi

# --- Fase 1: Preparación del Cliente ---
echo "==================================================================="
echo " FASE 1 (remota): Preparando el sistema local..."
echo "==================================================================="
echo "[PASO 1/5] Moviendo repositorios..."
mkdir -p /etc/zypp/repos.d.old && mv /etc/zypp/repos.d/* /etc/zypp/repos.d.old/ 2>/dev/null
echo "[PASO 2/5] Desactivando servicios de Zypper..."
if [ -d /etc/zypp/services.d ]; then sed -i 's/^\s*enabled\s*=\s*1/enabled = 0/g' /etc/zypp/services.d/*; fi
zypper --non-interactive verify >/dev/null
echo "[PASO 3/5] Des-registrando del SCC..."
SUSEConnect --cleanup
echo "[PASO 4/5] Regenerando IDs de la VM..."
rm -f /etc/machine-id /var/lib/dbus/machine-id && dbus-uuidgen --ensure && systemd-machine-id-setup
echo "[PASO 5/5] Limpiando Salt Minion..."
systemctl stop salt-minion && rm -rf /etc/salt/pki/minion /var/cache/salt
echo "✅ PREPARACIÓN LOCAL COMPLETADA."

# --- Fase 2: Registro en SUSE Manager (Método Pull) ---
echo ""
echo "==================================================================="
echo " FASE 2 (remota): Registrando en SUSE Manager..."
echo "==================================================================="
BOOTSTRAP_URL="http://${SUSE_MANAGER_HOST_REMOTE}/pub/bootstrap/${BOOTSTRAP_SCRIPT_NAME_REMOTE}"
echo "Descargando y ejecutando desde: $BOOTSTRAP_URL"
curl -Sks "$BOOTSTRAP_URL" | bash

REMOTE_SCRIPT_EOF

# --- Fin de la Ejecución ---
if [ $? -eq 0 ]; then
    echo ""
    echo "----------------------------------------------------------"
    echo "✅ PROCESO REMOTO COMPLETADO CON ÉXITO"
    echo "El cliente $CLIENT_SSH_TARGET debería estar registrado."
    echo "----------------------------------------------------------"
else
    echo "ERROR: El proceso remoto falló. Revisa la salida para más detalles."
    exit 1
fi

exit 0
