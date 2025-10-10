#!/bin/bash

# ==============================================================================
# TÍTULO:       add_dns_manual_multidomain.sh
# VERSIÓN:      2.6 (Lectura y escritura de SOA robustas, limpieza final)
# DESCRIPCIÓN:  Añade registros A y PTR de forma ordenada en un servidor BIND
#               Multi-Dominio y genera un log local de los cambios.
#
# ADVERTENCIA:  Este método es inherentemente más arriesgado que usar 'nsupdate'.
#               Úsese con precaución. Se recomienda encarecidamente planificar
#               la migración a un flujo de trabajo con 'nsupdate'.
# ==============================================================================

# --- CONFIGURACIÓN (¡IMPORTANTE! AJUSTA ESTOS VALORES) ---
DNS_MASTER="dns01.santpau.es"
DNS_SLAVE="dns02.santpau.es"
DNS_USER="root" # Usuario con permisos para editar ficheros y reiniciar named
ZONE_PATH="/var/lib/named/master"
LOG_FILE="dns_changes.log" # Fichero de log local
# ---------------------------------------------------------

# --- Recibir Parámetros ---
read -p "Introduce el nombre de dominio COMPLETO (ej: maquina.santpau.es): " FQDN
read -p "Introduce la dirección IP: " IP

if [ -z "$FQDN" ] || [ -z "$IP" ]; then
    echo "Error: El FQDN y la IP no pueden estar vacíos."
    exit 1
fi

# --- 1. Comprobación Previa Remota ---
echo "Verificando si los registros ya existen en $DNS_MASTER..."
if ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $FQDN @localhost" | grep -q .; then
    echo "Error: El registro A para '$FQDN' ya existe. Abortando."
    exit 1
fi
if ssh "${DNS_USER}@${DNS_MASTER}" "dig +short -x $IP @localhost" | grep -q .; then
    echo "Error: El registro PTR para '$IP' ya existe. Abortando."
    exit 1
fi

# --- 2. Confirmación del Usuario ---
echo "El registro no existe."
read -p "¿Quieres añadir '$FQDN' con IP '$IP'? (s/n): " CONFIRM
if [[ "$CONFIRM" != [sS] ]]; then
    echo "Operación cancelada."
    exit 0
fi

# --- 3. Ejecución Remota de Tareas ---
echo "Conectando a $DNS_MASTER para realizar los cambios..."
ssh_exit_status=0
# Se envía el bloque de comandos al servidor remoto. Si falla, se captura el código de salida.
ssh -T "${DNS_USER}@${DNS_MASTER}" bash -s -- "$FQDN" "$IP" "$ZONE_PATH" "$DNS_SLAVE" << 'EOF' || ssh_exit_status=$?
    set -e # El script remoto se detendrá inmediatamente si un comando falla

    # Recepción de parámetros en el servidor remoto
    FQDN=$1
    IP=$2
    ZONE_PATH=$3
    DNS_SLAVE=$4
    
    # Función para encontrar el fichero de zona directa correspondiente al FQDN
    find_forward_zone_file() {
        local fqdn=$1
        local domain_part=$fqdn
        while [[ "$domain_part" == *.* ]]; do
            local prospective_file="db.${domain_part}"
            if [ -f "${ZONE_PATH}/${prospective_file}" ]; then
                echo "$prospective_file"
                return 0
            fi
            # Si no se encuentra, se quita la parte izquierda del dominio y se vuelve a intentar
            domain_part=$(echo "$domain_part" | cut -d'.' -f2-)
        done
        return 1
    }

    echo "Buscando fichero de zona para $FQDN..."
    FORWARD_ZONE_FILENAME=$(find_forward_zone_file "$FQDN")
    if [ -z "$FORWARD_ZONE_FILENAME" ]; then
        echo "Error: No se pudo encontrar un fichero de zona directa para el dominio de '$FQDN'."
        exit 1
    fi
    
    # Construcción de nombres de ficheros y zonas
    FORWARD_OCTETS=$(echo "$IP" | cut -d'.' -f1-3)
    REVERSE_ZONE_FILENAME="db.${FORWARD_OCTETS}"
    REVERSE_ZONE_FILE="${ZONE_PATH}/${REVERSE_ZONE_FILENAME}"
    REVERSE_ZONE_NAME=$(echo "$IP" | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    FORWARD_ZONE_FILE="${ZONE_PATH}/${FORWARD_ZONE_FILENAME}"
    LAST_OCTET=$(echo "$IP" | awk -F. '{print $4}')
    HOSTNAME=$(echo "$FQDN" | cut -d'.' -f1)
    DOMAIN=$(echo "$FORWARD_ZONE_FILENAME" | sed 's/^db\.//')

    echo "Fichero de zona directa encontrado: $FORWARD_ZONE_FILE"
    echo "Fichero de zona inversa encontrado: $REVERSE_ZONE_FILE"

    if [ ! -f "$REVERSE_ZONE_FILE" ]; then
        echo "Error: El fichero de zona inversa $REVERSE_ZONE_FILE no existe."
        exit 1
    fi
    
    echo "Creando backups..."
    BACKUP_SUFFIX=$(date +"%Y%m%d-%H%M%S")
    cp -p "$FORWARD_ZONE_FILE" "${FORWARD_ZONE_FILE}-${BACKUP_SUFFIX}"
    cp -p "$REVERSE_ZONE_FILE" "${REVERSE_ZONE_FILE}-${BACKUP_SUFFIX}"

    # Función robusta para calcular el nuevo número de serie del SOA
    calculate_new_soa() {
        local file=$1
        # Busca el bloque SOA y extrae el primer campo numérico que parece un serial
        local old_soa=$(awk '/SOA/,/\)/ {if ($1 ~ /^[0-9]{10,}/) {print $1; exit}}' "$file")
        if [ -z "$old_soa" ]; then
            echo "Error: No se pudo leer el SOA del fichero $file." >&2
            return 1
        fi
        local old_date=${old_soa:0:8}
        local old_serial=${old_soa:8}
        local today=$(date +"%Y%m%d")
        if [ "$old_date" == "$today" ]; then
            new_serial=$(printf "%02d" $((10#$old_serial + 1)))
        else
            new_serial="01"
        fi
        echo "${today}${new_serial}"
    }

    NEW_SOA_FORWARD=$(calculate_new_soa "$FORWARD_ZONE_FILE")
    NEW_SOA_REVERSE=$(calculate_new_soa "$REVERSE_ZONE_FILE")

    echo "Actualizando números de serie SOA..."
    # Reemplaza la línea del serial dentro del bloque SOA sin depender de comentarios
    sed -i.bak -E "/IN\s+SOA\s+/,/\)/s/^\s*[0-9]{10,}/\t\t${NEW_SOA_FORWARD}/" "$FORWARD_ZONE_FILE"
    sed -i.bak -E "/IN\s+SOA\s+/,/\)/s/^\s*[0-9]{10,}/\t\t${NEW_SOA_REVERSE}/" "$REVERSE_ZONE_FILE"

    echo "Añadiendo nuevos registros de forma ordenada..."
    
    inserted_a=false
    ip_base=$(echo "$IP" | cut -d'.' -f1-3)
    for i in $(seq $((LAST_OCTET - 1)) -1 0); do
        prev_ip="${ip_base}.${i}"
        if grep -q -F "$prev_ip" "$FORWARD_ZONE_FILE"; then
            sed -i "/${prev_ip}/a ${HOSTNAME}\t\tIN\tA\t${IP}" "$FORWARD_ZONE_FILE"
            inserted_a=true
            break
        fi
    done
    if [ "$inserted_a" = false ]; then
        echo "No se encontró IP anterior en zona directa. Añadiendo al final..."
        echo -e "${HOSTNAME}\t\tIN\tA\t${IP}" >> "$FORWARD_ZONE_FILE"
    fi

    inserted_ptr=false
    for i in $(seq $((LAST_OCTET - 1)) -1 1); do
        if grep -q -E "^\s*${i}\s+" "$REVERSE_ZONE_FILE"; then
            sed -i "/^\s*${i}\s\+/a ${LAST_OCTET}\t\tIN\tPTR\t${FQDN}." "$REVERSE_ZONE_FILE"
            inserted_ptr=true
            break
        fi
    done
    if [ "$inserted_ptr" = false ]; then
        echo "No se encontró registro anterior en zona inversa. Añadiendo al final..."
        echo -e "${LAST_OCTET}\t\tIN\tPTR\t${FQDN}." >> "$REVERSE_ZONE_FILE"
    fi

    echo "Validando sintaxis de los ficheros modificados..."
    if ! named-checkzone "$DOMAIN" "$FORWARD_ZONE_FILE" > /dev/null 2>&1; then
        echo "¡ERROR DE SINTAXIS EN LA ZONA DIRECTA! Restaurando backup..."
        mv "${FORWARD_ZONE_FILE}-${BACKUP_SUFFIX}" "$FORWARD_ZONE_FILE"
        exit 1
    fi
    if ! named-checkzone "$REVERSE_ZONE_NAME" "$REVERSE_ZONE_FILE" > /dev/null 2>&1; then
        echo "¡ERROR DE SINTAXIS EN LA ZONA INVERSA! Restaurando backup..."
        mv "${REVERSE_ZONE_FILE}-${BACKUP_SUFFIX}" "$REVERSE_ZONE_FILE"
        mv "${FORWARD_ZONE_FILE}-${BACKUP_SUFFIX}" "$FORWARD_ZONE_FILE"
        exit 1
    fi
    echo "Validación de sintaxis correcta."

    echo "Recargando servicio named en el master (reload)..."
    if ! systemctl reload named; then
        echo "¡FALLO AL RECARGAR NAMED EN EL MASTER! Revisa el estado del servicio."
        exit 1
    fi
    
    echo "Recargando servicio named en el esclavo ($DNS_SLAVE)..."
    if ! ssh "$DNS_SLAVE" "systemctl reload named"; then
        echo "¡AVISO! Falló la recarga de named en el esclavo. Deberás hacerlo manualmente."
    fi

    echo "Moviendo backups a la carpeta 'old'..."
    mkdir -p "${ZONE_PATH}/old"
    mv "${FORWARD_ZONE_FILE}-${BACKUP_SUFFIX}" "${ZONE_PATH}/old/"
    mv "${REVERSE_ZONE_FILE}-${BACKUP_SUFFIX}" "${ZONE_PATH}/old/"
    
    echo "Limpiando ficheros .bak temporales..."
    rm -f "${FORWARD_ZONE_FILE}.bak" "${REVERSE_ZONE_FILE}.bak"

    echo "Proceso completado con éxito en el servidor."
EOF

# --- 4. Log de Cambios Local y Verificación Final ---
if [ $ssh_exit_status -eq 0 ]; then
    echo "Script remoto ejecutado con éxito."
    echo "Registrando cambio en $LOG_FILE..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ADD - FQDN: $FQDN, IP: $IP - Usuario: $USER" >> "$LOG_İLE"
    
    echo "Verificando los cambios:"
    sleep 3
    dig "$FQDN" @"$DNS_MASTER" | grep -A1 "ANSWER SECTION"
else
    echo "Error durante la ejecución remota (código de salida: $ssh_exit_status). No se generó log. Revisa los mensajes anteriores."
fi
