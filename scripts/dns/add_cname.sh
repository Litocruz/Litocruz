#!/bin/bash
# VERSIÓN 9.0 - SCRIPT DEDICADO PARA AÑADIR CNAME
# Respeta los permisos, usa 'reload' y tiene código claro.
set -e

# --- CONFIGURACIÓN ---
DNS_MASTER="dns01.santpau.es"
DNS_SLAVE="dns02.santpau.es"
DNS_USER="root"
ZONE_PATH="/var/lib/named/master"
LOG_FILE="dns_changes.log"

# --- LÓGICA ---
read -p "Introduce el nuevo ALIAS (FQDN): " FQDN
read -p "Introduce el HOST DESTINO (FQDN): " TARGET_FQDN

if [[ -z "$FQDN" ]] || [[ -z "$TARGET_FQDN" ]]; then
    echo "Error: Ambos campos son obligatorios."
    exit 1
fi

echo "Verificando registros..."
if [[ -n "$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $FQDN @localhost" 2>/dev/null)" ]]; then
    echo "Error: El alias '$FQDN' ya existe."
    exit 1
fi

if [[ -z "$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $TARGET_FQDN @localhost" 2>/dev/null)" ]]; then 
    read -p "AVISO: El host destino '$TARGET_FQDN' no existe. ¿Continuar? (s/n): " confirm_continue
    if [[ "$confirm_continue" != [sS] ]]; then
        echo "Operación cancelada."
        exit 0
    fi
fi

read -p "Crear alias '$FQDN' -> '$TARGET_FQDN'? (s/n): " confirm_create
if [[ "$confirm_create" != [sS] ]]; then
    echo "Operación cancelada."
    exit 0
fi

echo "Conectando a $DNS_MASTER..."
ssh_exit_status=0
ssh -T "${DNS_USER}@${DNS_MASTER}" << EOF || ssh_exit_status=$?
    set -e
    
    # Asignación de variables recibidas
    FQDN="${FQDN}"
    TARGET_FQDN="${TARGET_FQDN}"
    ZONE_PATH="${ZONE_PATH}"
    DNS_SLAVE="${DNS_SLAVE}"
    
    # --- Funciones ---
    find_fwd() {
        local fqdn=\$1
        local domain_part=\$fqdn
        while [[ "\$domain_part" == *.* ]]; do
            local p_file="db.\${domain_part}"
            if [ -f "\${ZONE_PATH}/\${p_file}" ]; then
                echo "\$p_file"
                return 0
            fi
            domain_part=\$(echo "\$domain_part" | cut -d'.' -f2-)
        done
        return 1
    }

    calc_soa() {
        local file=\$1
        local old_soa=\$(awk '/SOA/,/\)/ {if (\$1 ~ /^[0-9]{10,}/) {print \$1; exit}}' "\$file")
        if [ -z "\$old_soa" ]; then return 1; fi
        local old_date=\${old_soa:0:8}
        local old_serial=\${old_soa:8}
        local today=\$(date +"%Y%m%d")
        if [ "\$old_date" == "\$today" ]; then
            new_serial=\$(printf "%02d" \$((10#\$old_serial + 1)))
        else
            new_serial="01"
        fi
        echo "\${today}\${new_serial}"
    }

    # --- Lógica Principal ---
    FWD_FILE="\${ZONE_PATH}/\$(find_fwd "\$FQDN")"
    if [[ ! -f "\$FWD_FILE" ]]; then
        echo "Error: Fichero de zona no encontrado."
        exit 1
    fi

    BACKUP_SUFFIX=\$(date +"%Y%m%d-%H%M%S")
    cp -p "\$FWD_FILE" "\${FWD_FILE}-\${BACKUP_SUFFIX}"
    
    echo "Añadiendo CNAME de forma ordenada..."
    ALIAS_HOSTNAME=\$(echo "\$FQDN" | cut -d'.' -f1)

    # Lógica para insertar el CNAME después del último CNAME existente
    LAST_CNAME_LINE=\$(grep -n "IN\s\+CNAME" "\$FWD_FILE" | tail -n 1 | cut -d: -f1)
    if [ -n "\$LAST_CNAME_LINE" ]; then
        sed -i "\${LAST_CNAME_LINE}a \${ALIAS_HOSTNAME}\t\tIN\tCNAME\t\${TARGET_FQDN}." "\$FWD_FILE"
    else
        echo -e "\${ALIAS_HOSTNAME}\t\tIN\tCNAME\t\${TARGET_FQDN}." >> "\$FWD_FILE"
    fi

    NEW_SOA=\$(calc_soa "\$FWD_FILE")
    sed -i.bak -E "/IN\s+SOA\s+/,/\)/s/^\s*[0-9]{10,}/\t\t\${NEW_SOA}/" "\$FWD_FILE"
    rm -f "\${FWD_FILE}.bak"

    domain=\$(echo "\$FWD_FILE" | sed -E 's#.*/db\.(.*)#\1#')
    if ! named-checkzone "\$domain" "\$FWD_FILE" > /dev/null 2>&1; then
        echo "ERROR DE SINTAXIS. Restaurando backup..."
        mv "\${FWD_FILE}-\${BACKUP_SUFFIX}" "\$FWD_FILE"
        exit 1
    fi

    echo "Recargando servicio (reload)..."
    systemctl reload named
    
    # Intentamos recargar el esclavo, sin que el fallo sea crítico
    if ! ssh -o ConnectTimeout=5 "\$DNS_SLAVE" "systemctl reload named" &>/dev/null; then
        echo "AVISO: Fallo la recarga en el esclavo (posiblemente clave SSH no guardada)."
    fi

    mkdir -p "\${ZONE_PATH}/old"
    mv "\${FWD_FILE}-\${BACKUP_SUFFIX}" "\${ZONE_PATH}/old/"
EOF

if [ $? -eq 0 ]; then
    echo "Éxito."
    echo "Log generado."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ADD_CNAME - ALIAS: $FQDN -> $TARGET_FQDN - By: $USER" >> "$LOG_FILE"
    sleep 2
    echo "Verificando..."
    dig "$FQDN" @"$DNS_MASTER"
else
    echo "Error remoto."
fi
