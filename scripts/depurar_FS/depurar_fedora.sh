#!/bin/bash

# ==============================================================================
# Script para Depurar el Sistema de Archivos Raíz (/) en Fedora
#
# ADVERTENCIA: Ejecuta este script con precaución. Aunque está diseñado para
# ser seguro, siempre es buena idea entender lo que hace antes de ejecutarlo.
# Se recomienda tener copias de seguridad de los datos importantes.
# ==============================================================================

# --- Colores para la salida ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# --- Verificación de usuario root ---
if [[ $EUID -ne 0 ]]; then
   printf "${YELLOW}Este script debe ser ejecutado como root (o con sudo).${NC}\n" 
   exit 1
fi

# --- Función Principal ---
main() {
    printf "${GREEN}--- Iniciando limpieza del sistema de archivos raíz (/) ---${NC}\n\n"

    echo "Espacio en disco ANTES de la limpieza:"
    df -h /
    echo "------------------------------------------------"

    # 1. Limpiar caché de DNF
    printf "\n${YELLOW}[ACCIÓN 1/5] Limpiando la caché de paquetes de DNF...${NC}\n"
    dnf clean all
    printf "${GREEN}Caché de DNF limpiada.${NC}\n"

    # 2. Limpiar logs antiguos del journal de systemd
    printf "\n${YELLOW}[ACCIÓN 2/5] Limpiando logs antiguos de journald (se conservarán los últimos 100MB)...${NC}\n"
    #journalctl --vacuum-size=100M
    printf "${GREEN}Logs de journald limpiados.${NC}\n"

    # 3. Eliminar archivos de logs rotados y comprimidos
    printf "\n${YELLOW}[ACCIÓN 3/5] Eliminando archivos de log antiguos (.gz, .1, etc.) de /var/log...${NC}\n"
    #find /var/log -type f -name "*.gz" -delete
    #find /var/log -type f -regex ".*\.log\.[0-9]$" -delete
    printf "${GREEN}Logs antiguos eliminados.${NC}\n"

    # 4. Limpiar archivos temporales antiguos
    printf "\n${YELLOW}[ACCIÓN 4/5] Eliminando archivos temporales de más de 7 días en /tmp y /var/tmp...${NC}\n"
    # No se usa 'rm -rf' para evitar borrar archivos en uso. 'find' es más seguro.
    find /tmp -type f -mtime +7 -delete
    find /var/tmp -type f -mtime +7 -delete
    printf "${GREEN}Archivos temporales antiguos eliminados.${NC}\n"

    # 5. Eliminar kernels antiguos (excepto los 2 más recientes)
    printf "\n${YELLOW}[ACCIÓN 5/5] Buscando kernels antiguos para eliminar...${NC}\n"
    # dnf se encargará de preguntar por confirmación, lo cual es más seguro.
    OLD_KERNELS=$(dnf repoquery --installonly --latest-limit=-2 -q)
    if [ -n "$OLD_KERNELS" ]; then
        printf "${YELLOW}Se encontraron los siguientes kernels antiguos. DNF pedirá confirmación para eliminarlos:${NC}\n"
        echo "$OLD_KERNELS"
        dnf remove -y $OLD_KERNELS
    else
        printf "${GREEN}No se encontraron kernels antiguos para eliminar.${NC}\n"
    fi

    echo "------------------------------------------------"
    printf "\n${GREEN}--- Limpieza Finalizada ---${NC}\n\n"
    echo "Espacio en disco DESPUÉS de la limpieza:"
    df -h /
    printf "\n"
}

# --- Ejecutar la función principal ---
main
