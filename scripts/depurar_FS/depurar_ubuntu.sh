#!/bin/bash

# Script de Depuración de Sistema de Archivos en Ubuntu

echo "=== Iniciando Depuración del Sistema de Archivos ==="
echo "Este script buscará archivos temporales, caché y archivos grandes."
echo "Siempre pedirá confirmación antes de eliminar cualquier cosa."
echo ""

# --- Función para mostrar el uso del disco antes y después ---
mostrar_uso_disco() {
    echo "--- Uso actual del disco ---"
    df -h /
    echo "----------------------------"
}

# --- 1. Limpieza de Caché de APT ---
limpiar_apt_cache() {
    echo "--- Paso 1: Limpiando la caché de paquetes de APT ---"
    echo "Estos son los paquetes .deb descargados que APT guarda."
    echo "Puedes liberarlos de forma segura."
    read -p "¿Deseas limpiar la caché de APT? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt clean
        echo "Caché de APT limpiada."
        mostrar_uso_disco
    else
        echo "Limpieza de caché de APT omitida."
    fi
    echo ""
}

# --- 2. Eliminación de Paquetes Huérfanos ---
eliminar_paquetes_huerfanos() {
    echo "--- Paso 2: Eliminando paquetes huérfanos (autoremove) ---"
    echo "Estos son paquetes instalados como dependencias que ya no son necesarios."
    echo "Se recomienda eliminarlos, pero revísalos con 'sudo apt autoremove --dry-run'."
    read -p "¿Deseas ejecutar 'sudo apt autoremove'? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt autoremove
        echo "Paquetes huérfanos eliminados."
        mostrar_uso_disco
    else
        echo "Eliminación de paquetes huérfanos omitida."
    fi
    echo ""
}

# --- 3. Limpieza de Archivos Temporales (/tmp) ---
limpiar_tmp() {
    echo "--- Paso 3: Limpiando archivos temporales en /tmp ---"
    echo "Contenido de /tmp (solo los 10 elementos más grandes):"
    sudo du -sh /tmp/* 2>/dev/null | sort -rh | head -n 10
    read -p "¿Deseas eliminar todos los archivos en /tmp? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf /tmp/*
        echo "Archivos temporales en /tmp eliminados."
        mostrar_uso_disco
    else
        echo "Limpieza de /tmp omitida."
    fi
    echo ""
}

# --- 4. Limpieza de Caché de Usuario (~/.cache) ---
limpiar_cache_usuario() {
    echo "--- Paso 4: Limpiando caché de usuario en ~/.cache ---"
    echo "Contenido de ~/.cache (solo los 10 elementos más grandes):"
    du -sh ~/.cache/* 2>/dev/null | sort -rh | head -n 10
    read -p "¿Deseas eliminar el contenido de ~/.cache? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Se elimina el contenido, no el directorio .cache en sí
        rm -rf ~/.cache/*
        echo "Caché de usuario en ~/.cache eliminada."
        mostrar_uso_disco
    else
        echo "Limpieza de ~/.cache omitida."
    fi
    echo ""
}

# --- 5. Limpieza de Logs del Sistema (journalctl) ---
limpiar_logs() {
    echo "--- Paso 5: Limpiando logs del sistema (journalctl) ---"
    echo "Uso actual de logs en disco:"
    sudo journalctl --disk-usage
    read -p "¿Deseas limitar el tamaño de los logs a 500MB? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo journalctl --vacuum-size=500M
        echo "Logs del sistema limitados a 500MB."
        sudo journalctl --disk-usage
        mostrar_uso_disco
    else
        echo "Limpieza de logs omitida."
    fi
    echo ""
}


# --- 6. Informe de Archivos y Directorios Grandes ---
informe_archivos_grandes() {
    echo "--- Paso 6: Generando informe de los 20 archivos/directorios más grandes en / ---"
    echo "Esto puede tardar un poco..."
    # Limitar la búsqueda para evitar /proc, /sys, /dev
    sudo du -aSh / --exclude={/proc,/sys,/dev,/snap} 2>/dev/null | sort -rh | head -n 20
    echo ""
    echo "Revisa la salida anterior para identificar posibles archivos o directorios grandes que puedas querer eliminar manualmente."
    echo "Puedes usar 'rm -rf <ruta_del_archivo_o_directorio>' con mucha precaución."
    echo ""
}

# --- Ejecución del script ---
mostrar_uso_disco
limpiar_apt_cache
eliminar_paquetes_huerfanos
limpiar_tmp
limpiar_cache_usuario
limpiar_logs
informe_archivos_grandes

echo "=== Depuración Completada ==="
mostrar_uso_disco
echo "Recuerda que para una limpieza más profunda, puedes considerar: "
echo "  - Borrar kernels antiguos."
echo "  - Revisar directorios de descargas y documentos personales."
echo "  - Eliminar Snaps o Flatpaks no usados."
