#!/bin/bash

# ==============================================================================
# Script: check_dns.sh
# Descripción: Realiza nslookup masivos.
# Detecta automáticamente si el primer argumento es un archivo o una lista.
# ==============================================================================

# Colores para que se vea bonito
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función que hace el trabajo sucio
hacer_nslookup() {
    local target=$1
    echo -e "${CYAN}----------------------------------------${NC}"
    echo -e "🔎 Consultando: ${GREEN}$target${NC}"
    
    # Ejecutamos nslookup y filtramos un poco la salida para que sea limpia
    # Si quieres ver TODO el detalle, quita el "| tail -n +4"
    result=$(nslookup "$target" 2>&1)
    
    if [[ $result == *"NXDOMAIN"* || $result == *"server can't find"* ]]; then
        echo -e "${RED}❌ No encontrado (NXDOMAIN) o error.${NC}"
    else
        # Mostramos solo las líneas relevantes (Address)
        echo "$result" | grep -A 1 "Name:" || echo "$result" | grep "Address:"
    fi
}

# --- LÓGICA PRINCIPAL ---

# 1. Verificar si hay argumentos
if [ $# -eq 0 ]; then
    echo "Uso:"
    echo "  1. Con archivo:  $0 lista.txt"
    echo "  2. Con lista:    $0 google.com yahoo.com"
    echo "  3. Con llaves:   $0 servidor{01..05}.midominio.local"
    exit 1
fi

# 2. Detectar si el primer argumento es un archivo existente
if [ -f "$1" ]; then
    echo -e "${GREEN}[MODO ARCHIVO]${NC} Leyendo desde '$1'..."
    while IFS= read -r linea || [[ -n "$linea" ]]; do
        # Ignorar líneas vacías
        [[ -z "$linea" ]] && continue
        hacer_nslookup "$linea"
    done < "$1"
else
    # 3. Si no es un archivo, asumimos que son argumentos (lista o expansión de llaves)
    echo -e "${GREEN}[MODO ARGUMENTOS]${NC} Procesando $# hosts..."
    for host in "$@"; do
        hacer_nslookup "$host"
    done
fi

echo -e "${CYAN}----------------------------------------${NC}"
echo "✅ Finalizado."
