#!/bin/bash

# --- Script de Diagnóstico para el Filesystem Raíz en SUSE ---
# Este script es seguro y no modifica ni borra ningún archivo.
# Ejecútalo con sudo para obtener la información más precisa.

# Comprobar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo "Por favor, ejecuta este script como root o con sudo." 
   exit 1
fi

echo "=========================================================="
echo "      INFORME DE USO DEL FILESYSTEM RAÍZ (/)          "
echo "=========================================================="
echo ""

# 1. Uso general del disco
echo "--- 1. Uso General del Disco ---"
df -h /
echo ""

# Comprobar si es Btrfs para un informe más detallado
FSTYPE=$(findmnt -n -o FSTYPE /)
if [ "$FSTYPE" = "btrfs" ]; then
    echo "--- (Detalle Btrfs) Uso Real del Disco ---"
    btrfs filesystem df /
    echo ""
fi

# 2. Los 10 directorios más grandes en la raíz
echo "--- 2. Top 10 Directorios más Grandes en / ---"
du -ah --max-depth=1 / 2>/dev/null | sort -rh | head -n 10
echo ""
echo "Consejo: Revisa los directorios /var, /usr, /opt y /root."
echo ""

# 3. Análisis de Snapshots de Btrfs (Snapper)
if command -v snapper &> /dev/null; then
    echo "--- 3. Análisis de Snapshots de Snapper (Causa Común de Espacio Lleno) ---"
    SNAPSHOT_COUNT=$(snapper list | wc -l)
    echo "Número total de snapshots encontrados: $SNAPSHOT_COUNT"
    echo ""
    echo "Uso de espacio por snapshots:"
    snapper status /
    echo ""
    echo "Para listar todos los snapshots, ejecuta: sudo snapper list"
    echo "Para borrar snapshots viejos (ej. del 100 al 200), ejecuta:"
    echo "# sudo snapper delete --sync 100-200"
    echo ""
else
    echo "--- 3. Snapper no encontrado. Omitiendo análisis de snapshots. ---"
    echo ""
fi

# 4. Limpieza Segura Sugerida
echo "--- 4. Acciones de Limpieza Segura Sugeridas ---"
echo "Puedes liberar espacio de forma segura ejecutando los siguientes comandos:"
echo ""
echo "# Limpiar la caché de paquetes de Zypper:"
echo "sudo zypper clean --all"
echo ""
echo "# Reducir el tamaño de los logs del sistema (ej. a 200MB):"
echo "sudo journalctl --vacuum-size=200M"
echo ""

# 5. Kernels Antiguos
echo "--- 5. Kernels Instalados ---"
echo "Los kernels antiguos pueden ocupar espacio en /boot. Puedes eliminar los que no uses."
echo "Kernel actual: $(uname -r)"
echo "Kernels instalados:"
rpm -qa | grep kernel-default | sort
echo ""
echo "Para eliminar un kernel antiguo (ejemplo):"
echo "# sudo zypper rm kernel-default-5.3.18-22"
echo "¡CUIDADO! Deja siempre el kernel actual y el anterior por seguridad."
echo ""

echo "=========================================================="
echo "                  FIN DEL INFORME                     "
echo "=========================================================="
