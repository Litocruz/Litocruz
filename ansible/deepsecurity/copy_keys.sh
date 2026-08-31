#!/bin/bash

# ==============================================================================
# Script: copy_keys_from_file.sh
# Descripción: Lee un archivo de texto con nombres de servidores y distribuye
# la clave pública SSH. Soporta sshpass y limpieza de líneas vacías.
# ==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 1. VERIFICACIÓN DE ARGUMENTOS ---
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Error: Debes especificar el archivo con la lista de servidores.${NC}"
    echo "Uso: $0 <archivo_servidores.txt>"
    exit 1
fi

SERVER_LIST="$1"

if [ ! -f "$SERVER_LIST" ]; then
    echo -e "${RED}Error: El archivo '$SERVER_LIST' no existe.${NC}"
    exit 1
fi

# --- 2. CONFIGURACIÓN DE USUARIO ---
echo -e "${YELLOW}--- Configuración de Despliegue SSH ---${NC}"
read -p "Usuario remoto (ej. root): " REMOTE_USER
[[ -z "$REMOTE_USER" ]] && REMOTE_USER="root"

USE_SSHPASS=false
if command -v sshpass &> /dev/null; then
    echo "Se ha detectado 'sshpass'."
    read -p "¿Deseas usar una contraseña común? (s/n): " use_pass
    if [[ "$use_pass" =~ ^[Ss]$ ]]; then
        USE_SSHPASS=true
        read -s -p "Introduce la contraseña común: " REMOTE_PASS
        echo ""
    fi
else
    echo -e "${YELLOW}[AVISO] 'sshpass' no instalado. Se pedirá contraseña manual.${NC}"
fi

# --- 3. PROCESAMIENTO DEL ARCHIVO ---
echo ""
echo -e "${YELLOW}Leyendo servidores desde: $SERVER_LIST ...${NC}"

# Leemos el archivo línea por línea
while IFS= read -r server || [[ -n "$server" ]]; do
    
    # Limpieza: quitamos espacios en blanco y posibles caracteres de retorno de carro (\r) de Windows
    server=$(echo "$server" | tr -d '\r' | xargs)

    # Saltamos líneas vacías o comentarios (que empiecen por #)
    if [[ -z "$server" || "$server" == \#* ]]; then
        continue
    fi

    echo -e "--------------------------------------------------"
    echo -e "Procesando: ${YELLOW}$server${NC}"

    # Verificación de Ping
    ping -c 1 -W 1 "$server" &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] El servidor no responde a ping. Saltando...${NC}"
        continue
    fi

    # Ejecución de copia de llave
    if [ "$USE_SSHPASS" = true ]; then
        sshpass -p "$REMOTE_PASS" ssh-copy-id -o StrictHostKeyChecking=no "$REMOTE_USER@$server"
    else
        ssh-copy-id -o StrictHostKeyChecking=no "$REMOTE_USER@$server"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK] Clave copiada.${NC}"
    else
        echo -e "${RED}[FALLO] Error al copiar clave.${NC}"
    fi

done < "$SERVER_LIST"

echo ""
echo -e "${GREEN}=== Proceso Finalizado ===${NC}"
