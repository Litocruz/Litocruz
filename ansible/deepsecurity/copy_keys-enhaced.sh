#!/bin/bash

# ==============================================================================
# Script: generar_inventario_dinamico_v2.sh
# Corrección: Se fuerza la lectura desde /dev/tty para las preguntas interactivas.
# ==============================================================================

# --- Variables y Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ARCHIVO_ENTRADA="servidores.txt"
ARCHIVO_BACKUP="${ARCHIVO_ENTRADA}.bak"
ARCHIVO_SALIDA="inventario_ansible.ini"

# --- Verificaciones ---
if [ ! -f "$ARCHIVO_ENTRADA" ]; then
    echo -e "${RED}Error: No encuentro el archivo '$ARCHIVO_ENTRADA'.${NC}"
    exit 1
fi

if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}Error: Necesitas instalar 'sshpass'.${NC}"
    exit 1
fi

# --- Preparativos ---
cp "$ARCHIVO_ENTRADA" "$ARCHIVO_BACKUP"
echo -e "${BLUE}[INFO] Copia de seguridad creada: $ARCHIVO_BACKUP${NC}"

if [ ! -f "$ARCHIVO_SALIDA" ]; then
    echo "# Inventario generado el $(date)" > "$ARCHIVO_SALIDA"
fi

LAST_USER="root"
LAST_PASS=""

# --- Bucle Principal ---
while IFS= read -r server || [[ -n "$server" ]]; do
    
    server=$(echo "$server" | tr -d '\r' | xargs)
    if [[ -z "$server" || "$server" == \#* ]]; then continue; fi

    if ! grep -q "^$server$" "$ARCHIVO_ENTRADA"; then
        continue 
    fi

    echo -e "\n--------------------------------------------------"
    echo -e "Procesando: ${YELLOW}$server${NC}"

    # 1. Ping Check
    ping -c 1 -W 1 "$server" &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}[SKIP] El servidor no responde a ping.${NC}"
        continue
    fi

    # 2. Credenciales (CORREGIDO: lee desde /dev/tty)
    echo "Introduce credenciales para $server:"
    
    # Forzamos lectura de teclado con < /dev/tty
    read -p "  Usuario [$LAST_USER]: " INPUT_USER < /dev/tty
    CURRENT_USER="${INPUT_USER:-$LAST_USER}"

    if [[ -n "$LAST_PASS" ]]; then
        read -p "  ¿Usar la misma contraseña anterior? (S/n): " USE_LAST_PASS < /dev/tty
        if [[ "$USE_LAST_PASS" =~ ^[Nn]$ ]]; then
            read -s -p "  Nueva Contraseña: " CURRENT_PASS < /dev/tty; echo ""
        else
            CURRENT_PASS="$LAST_PASS"
        fi
    else
        read -s -p "  Contraseña: " CURRENT_PASS < /dev/tty; echo ""
    fi

    LAST_USER="$CURRENT_USER"
    LAST_PASS="$CURRENT_PASS"

    # 3. Intentar SSH Copy ID
    echo -e "Conectando..."
    sshpass -p "$CURRENT_PASS" ssh-copy-id -o StrictHostKeyChecking=no "$CURRENT_USER@$server" > /dev/null 2>&1
    RET_CODE=$?

    # 4. Resultado
    if [ $RET_CODE -eq 0 ]; then
        echo -e "${GREEN}[EXITO] Llave copiada.${NC}"
        
        LINEA_NUEVA="$server ansible_user=\"$CURRENT_USER\""
        echo "$LINEA_NUEVA" >> "$ARCHIVO_SALIDA"
        
        sed -i "/^$server$/d" "$ARCHIVO_ENTRADA"
        
        echo -e "   -> Agregado a inventario y ${BLUE}eliminado de pendiente${NC}."
    else
        echo -e "${RED}[FALLO] Credenciales inválidas o error SSH.${NC}"
    fi

done < "$ARCHIVO_BACKUP"

rm "$ARCHIVO_BACKUP"
echo -e "\n${GREEN}=== Proceso Finalizado ===${NC}"
echo "Servidores restantes: $(wc -l < "$ARCHIVO_ENTRADA")"
