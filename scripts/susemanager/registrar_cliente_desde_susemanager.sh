#!/bin/bash

# ==============================================================================
# Script Maestro para Registrar un Cliente en SUSE Manager
#
# USO: sudo ./registra_cliente.sh <FQDN_DEL_CLIENTE>
# EJEMPLO: sudo ./registra_cliente.sh webpub03.santpau.es
#
# Este script debe ejecutarse DESDE EL SERVIDOR DE SUSE MANAGER como root.
#
# Realiza dos fases:
# 1. FASE DE PREPARACIÓN: Se conecta por SSH al cliente y ejecuta un script
#    de limpieza (mueve repos, des-registra, regenera IDs, limpia salt).
# 2. FASE DE REGISTRO: Ejecuta el método "push" para registrar el cliente
#    usando el script de bootstrap seleccionado.
# ==============================================================================

# --- Variables y Comprobaciones Iniciales ---
CLIENT_FQDN=$1
BOOTSTRAP_DIR="/srv/www/htdocs/pub/bootstrap"

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Este script debe ser ejecutado como 'root' o con 'sudo'."
   exit 1
fi

if [ -z "$CLIENT_FQDN" ]; then
    echo "ERROR: No se ha especificado el FQDN del cliente."
    echo "USO: $0 <FQDN_DEL_CLIENTE>"
    exit 1
fi

# --- Selección del Script de Bootstrap ---
echo "Buscando scripts de bootstrap en $BOOTSTRAP_DIR..."
PS3=$'\n'"Selecciona el script de bootstrap a usar para $CLIENT_FQDN: "
# Creamos un array con los nombres de los scripts
mapfile -t scripts < <(ls -1 "$BOOTSTRAP_DIR" | grep '\.sh$')
if [ ${#scripts[@]} -eq 0 ]; then
    echo "ERROR: No se encontraron scripts de bootstrap en $BOOTSTRAP_DIR."
    exit 1
fi

select SELECTED_SCRIPT in "${scripts[@]}"; do
    if [[ -n "$SELECTED_SCRIPT" ]]; then
        echo "Has seleccionado: $SELECTED_SCRIPT"
        break
    else
        echo "Selección inválida. Inténtalo de nuevo."
    fi
done

# --- Fase 1: Ejecución del Script de Preparación en el Cliente ---
echo ""
echo "=============================================================================="
echo " FASE 1: Ejecutando script de preparación en $CLIENT_FQDN..."
echo "=============================================================================="

ssh -o StrictHostKeyChecking=no "root@$CLIENT_FQDN" 'bash -s' << 'PREP_SCRIPT_EOF'

#!/bin/bash
# --- Script de preparación que se ejecuta en el cliente ---
echo "--- Iniciando la preparación del sistema para SUSE Manager ---"

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

echo "✅ PREPARACIÓN DEL CLIENTE COMPLETADA"
PREP_SCRIPT_EOF

# Comprobar si la Fase 1 tuvo éxito
if [ $? -ne 0 ]; then
    echo "ERROR: El script de preparación falló en $CLIENT_FQDN. Abortando."
    exit 1
fi

# --- Fase 2: Ejecución del Script de Registro (Método Push) ---
echo ""
echo "=============================================================================="
echo " FASE 2: Registrando $CLIENT_FQDN con el script $SELECTED_SCRIPT..."
echo "=============================================================================="

cat "$BOOTSTRAP_DIR/$SELECTED_SCRIPT" | ssh "root@$CLIENT_FQDN" /bin/bash

if [ $? -eq 0 ]; then
    echo ""
    echo "----------------------------------------------------------"
    echo "✅ REGISTRO COMPLETADO"
    echo "El sistema $CLIENT_FQDN debería aparecer en SUSE Manager en breve."
    echo "----------------------------------------------------------"
else
    echo "ERROR: La fase de registro falló. Revisa la salida para más detalles."
    exit 1
fi

exit 0
