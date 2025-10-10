#!/bin/bash
# VERSIÓN 13.0 - SCRIPT REFACTORIZADO PARA MAYOR CLARIDAD Y ROBUSTEZ
set -e

# --- CONFIGURACIÓN ---
DNS_MASTER="dns01.santpau.es"
DNS_SLAVE="dns02.santpau.es"
DNS_USER="root"
ZONE_PATH="/var/lib/named/master"
LOG_FILE="dns_changes.log"

# --- LÓGICA ---
ACTION="ADD"
read -p "Introduce el nombre de dominio COMPLETO (FQDN): " FQDN
read -p "Introduce la dirección IP: " IP

if [[ -z "$FQDN" ]] || [[ -z "$IP" ]]; then
    echo "Error: FQDN e IP son obligatorios."
    exit 1
fi

echo "Verificando registros existentes..."
if [[ -n "$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $FQDN @localhost" 2>/dev/null)" ]]; then
    echo "Error: El registro A para '$FQDN' ya existe."
    exit 1
fi

PTR_RECORD=$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short -x $IP @localhost" 2>/dev/null)
if [[ -n "$PTR_RECORD" ]]; then
    read -p "AVISO: La IP '$IP' ya tiene un PTR ('$PTR_RECORD'). ¿Forzar reasignación a '$FQDN'? (s/n): " CONFIRM_REASSIGN
    if [[ "$CONFIRM_REASSIGN" =~ ^[sS]$ ]]; then
        ACTION="REASSIGN_PTR"
        OLD_FQDN_OF_PTR=${PTR_RECORD%.}
    else
        echo "Operación cancelada."
        exit 0
    fi
fi

if [[ -z "$CONFIRM_REASSIGN" ]]; then
    read -p "¿Añadir '$FQDN' con IP '$IP'? (s/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operación cancelada."
        exit 0
    fi
fi

echo "Conectando a $DNS_MASTER para realizar los cambios..."

# --- INICIO DEL BLOQUE SSH ---
ssh -T "${DNS_USER}@${DNS_MASTER}" << EOF
    # ACTIVAMOS DEPURACIÓN PARA VER CADA COMANDO
    set -ex
    
    # Variables pasadas desde el script local
    ACTION="${ACTION}"
    FQDN="${FQDN}"
    IP="${IP}"
    OLD_FQDN_OF_PTR="${OLD_FQDN_OF_PTR}"
    ZONE_PATH="${ZONE_PATH}"
    DNS_SLAVE="${DNS_SLAVE}"
    
    # --- Funciones auxiliares ---
    find_fwd() {
        # ... (sin cambios en las funciones)
        local fqdn=\$1; local domain_part=\$fqdn
        while [[ "\$domain_part" == *.* ]]; do
            local p="db.\${domain_part}"; if [ -f "\${ZONE_PATH}/\${p}" ]; then echo "\$p"; return 0; fi
            domain_part=\$(echo "\$domain_part" | cut -d'.' -f2-)
        done
        return 1
    }

    calc_soa() {
        # ... (sin cambios en las funciones)
        local file=\$1; local old=\$(awk '/SOA/,/\)/ {if (\$1 ~ /^[0-9]{10,}/) {print \$1; exit}}' "\$file")
        if [ -z "\$old" ]; then return 1; fi
        local old_d=\${old:0:8}; local old_s=\${old:8}; local today=\$(date +"%Y%m%d")
        if [ "\$old_d" == "\$today" ]; then new_s=\$(printf "%02d" \$((10#\$old_s + 1))); else new_s="01"; fi
        echo "\${today}\${new_s}"
    }
    
    # --- Preparación ---
    FWD_FILE="\${ZONE_PATH}/\$(find_fwd "\$FQDN")"
    REV_FILE="\${ZONE_PATH}/db.\$(echo "\$IP" | cut -d'.' -f1-3)"

    if [[ ! -f "\$FWD_FILE" ]] || [[ ! -f "\$REV_FILE" ]]; then 
        echo "Error: Fichero de zona no encontrado para FQDN '\$FQDN' o IP '\$IP'."
        exit 1
    fi

    FILES_TO_UPDATE=("\$FWD_FILE" "\$REV_FILE")
    BACKUP_SUFFIX=\$(date +"%Y%m%d-%H%M%S")
    
    # --- Creación de Backups (LÓGICA CORREGIDA) ---
    echo "Creando backups..."
    for f in "\${FILES_TO_UPDATE[@]}"; do
        # Construimos el nombre del backup de forma explícita
        FILENAME=\$(basename "\$f")
        cp -p "\$f" "\${ZONE_PATH}/\${FILENAME}-\${BACKUP_SUFFIX}"
    done
    
    HOSTNAME=\$(echo "\$FQDN" | cut -d'.' -f1)
    LAST_OCTET=\$(echo "\$IP" | awk -F. '{print \$4}')
    
    # --- Modificación de Zonas (sin cambios en esta sección) ---
    # ... (toda la lógica de sed para A, PTR y SOA se mantiene igual)
    # 1. Añadir registro A (Directo)
    ip_base=\$(echo "\$IP" | cut -d'.' -f1-3); inserted=false
    for i in \$(seq \$((LAST_OCTET-1)) -1 0); do
        prev_ip="\${ip_base}.\${i}"
        if grep -q -F "\$prev_ip" "\$FWD_FILE"; then
            sed -i "/\${prev_ip}/a \${HOSTNAME}\t\tIN\tA\t\${IP}" "\$FWD_FILE"; inserted=true; break
        fi
    done
    if [ "\$inserted" = false ]; then
        echo -e "\${HOSTNAME}\t\tIN\tA\t\${IP}" >> "\$FWD_FILE"
    fi
    
    # 2. Añadir o modificar registro PTR (Reverso)
    if [[ "\$ACTION" == "ADD" ]]; then
        inserted=false
        for i in \$(seq \$((LAST_OCTET-1)) -1 1); do
            if grep -q -E "^\s*\${i}\s+" "\$REV_FILE"; then
                sed -i "/^\s*\${i}\s\+/a \${LAST_OCTET}\t\tIN\tPTR\t\${FQDN}." "\$REV_FILE"; inserted=true; break
            fi
        done
        if [ "\$inserted" = false ]; then
            echo -e "\${LAST_OCTET}\t\tIN\tPTR\t\${FQDN}." >> "\$REV_FILE"
        fi
    else # REASSIGN_PTR
        echo "Modificando registro PTR existente..."
        OLD_FQDN_OF_PTR_ESC=\$(echo "\$OLD_FQDN_OF_PTR" | sed 's/\\./\\\\./g')
        sed -i "s/^\s*\${LAST_OCTET}\s\+IN\s\+PTR\s\+\${OLD_FQDN_OF_PTR_ESC}\..*$/\${LAST_OCTET}\t\tIN\tPTR\t\${FQDN}./" "\$REV_FILE"
    fi

    # 3. Actualizar Serial (SOA)
    echo "Actualizando números de serie (SOA)..."
    for f in "\${FILES_TO_UPDATE[@]}"; do
        NEW_SOA=\$(calc_soa "\$f")
        sed -i.bak -E "/IN\s+SOA\s+/,/\)/s/^\s*[0-9]{10,}/\t\t\${NEW_SOA}/" "\$f"
        rm -f "\${f}.bak"
    done
    
    # --- Validación y Aplicación ---
    echo "Validando sintaxis de las zonas modificadas..."
    for f in "\${FILES_TO_UPDATE[@]}"; do
        domain=\$(echo "\$f" | sed -E 's#.*/db\\.(.*)#\\1#')
        if [[ \$domain =~ ^[0-9] ]]; then 
            name=\$(echo "\$domain" | awk -F. '{print \$3"."\$2"."\$1".in-addr.arpa"}')
        else
            name=\$domain
        fi
        
        if ! named-checkzone "\$name" "\$f" > /dev/null 2>&1; then
            echo "ERROR DE SINTAXIS EN \$f. Restaurando backups...";
            for fr in "\${FILES_TO_UPDATE[@]}"; do
                FILENAME_TO_RESTORE=\$(basename "\$fr")
                BACKUP_FILE_TO_RESTORE="\${ZONE_PATH}/\${FILENAME_TO_RESTORE}-\${BACKUP_SUFFIX}"
                mv "\$BACKUP_FILE_TO_RESTORE" "\$fr"
            done
            exit 1
        fi
    done

    echo "Recargando servicio BIND (named)...";
    systemctl reload named
    
    if ! ssh -o ConnectTimeout=5 "\$DNS_SLAVE" "systemctl reload named" &>/dev/null; then 
        echo "AVISO: Falló la recarga en el servidor esclavo \$DNS_SLAVE."
    fi
    
    # --- Limpieza de backups (LÓGICA CORREGIDA Y CON DEPURACIÓN) ---
    echo "Limpiando backups..."
    mkdir -p "\${ZONE_PATH}/old"
    for f in "\${FILES_TO_UPDATE[@]}"; do
        # Construimos el nombre del backup de forma explícita
        FILENAME=\$(basename "\$f")
        BACKUP_FILE_TO_MOVE="\${ZONE_PATH}/\${FILENAME}-\${BACKUP_SUFFIX}"
        echo "Intentando mover: \${BACKUP_FILE_TO_MOVE}"
        # Usamos -v para que el comando mv nos diga qué está haciendo
        mv -v "\$BACKUP_FILE_TO_MOVE" "\${ZONE_PATH}/old/"
    done
EOF
# --- FIN DEL BLOQUE SSH ---
ssh_exit_status=$?

if [ $ssh_exit_status -eq 0 ]; then
    echo "Éxito: Los cambios se aplicaron correctamente en $DNS_MASTER."
    echo "Log generado en $LOG_FILE."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $ACTION - FQDN: $FQDN, IP: $IP - By: $USER" >> "$LOG_FILE"
    sleep 1
    echo "Verificando resolución DNS..."
    dig "$FQDN" @"$DNS_MASTER"
else
    echo "Error Remoto: La operación en $DNS_MASTER falló (código de salida: $ssh_exit_status)."
fi
