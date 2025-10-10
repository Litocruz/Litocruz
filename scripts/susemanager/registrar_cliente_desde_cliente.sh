#!/bin/bash

# ==============================================================================
# Script para PREPARAR y REGISTRAR un cliente en SUSE Manager
#
# USO: sudo ./registrar_cliente.sh
#
# Este script se ejecuta DIRECTAMENTE EN LA MÁQUINA CLIENTE como root.
#
# FASES:
# 1. Conexión a SUSE Manager para obtener la lista de scripts de bootstrap.
# 2. Preparación y limpieza local del cliente.
# 3. Registro del cliente usando el script seleccionado.
# ==============================================================================

# --- Variables y Comprobaciones ---
SUSE_MANAGER_HOST="susemanager01.santpau.es"
BOOTSTRAP_DIR="/srv/www/htdocs/pub/bootstrap"

# --- CREDENCIALES (ADVERTENCIA DE SEGURIDAD) ---
SSH_USER="root"

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Este script debe ser ejecutado como 'root' o con 'sudo'."
   exit 1
fi
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: El comando 'sshpass' no está instalado. Por favor, instálalo con 'sudo zypper install sshpass'."
    exit 1
fi

# --- Fase 1: Obtener y Seleccionar Script de Bootstrap ---
echo "==================================================================="
echo " FASE 1: Conectando a $SUSE_MANAGER_HOST para obtener lista de scripts..."
echo "==================================================================="

# Comando SSH para listar los archivos
SSH_COMMAND="ssh -o StrictHostKeyChecking=no $SSH_USER@$SUSE_MANAGER_HOST"
SCRIPT_LIST=$($SSH_COMMAND ls -1 "$BOOTSTRAP_DIR" | grep '\.sh$')

if [ -z "$SCRIPT_LIST" ]; then
    echo "ERROR: No se pudieron obtener los scripts de bootstrap desde $SUSE_MANAGER_HOST."
    echo "Comprueba la conexión, las credenciales y la ruta del directorio."
    exit 1
fi

# Crear el menú de selección
mapfile -t scripts < <(echo "$SCRIPT_LIST")
PS3=$'\n'"Selecciona el script de bootstrap a usar: "
select BOOTSTRAP_SCRIPT_NAME in "${scripts[@]}"; do
    if [[ -n "$BOOTSTRAP_SCRIPT_NAME" ]]; then
        echo "Has seleccionado: $BOOTSTRAP_SCRIPT_NAME"
        break
    else
        echo "Selección inválida. Inténtalo de nuevo."
    fi
done

# --- Fase 2: Preparación del Cliente ---
echo ""
echo "==================================================================="
echo " FASE 2: Preparando el sistema local..."
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
echo "PREPARACIÓN LOCAL COMPLETADA."

# --- Fase 3: Registro en SUSE Manager (Método Pull) ---
echo ""
echo "==================================================================="
echo " FASE 3: Registrando en SUSE Manager..."
echo "==================================================================="
BOOTSTRAP_URL="http://${SUSE_MANAGER_HOST}/pub/bootstrap/${BOOTSTRAP_SCRIPT_NAME}"
echo "Descargando y ejecutando desde: $BOOTSTRAP_URL"
curl -Sks "$BOOTSTRAP_URL" | bash

if [ $? -eq 0 ]; then
    echo ""
    echo "----------------------------------------------------------"
    echo "REGISTRO COMPLETADO"
    echo "----------------------------------------------------------"
else
    echo "ERROR: El script de registro falló."
    exit 1
fi

exit 0
