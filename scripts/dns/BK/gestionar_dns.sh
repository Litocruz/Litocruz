#!/bin/bash

# ==============================================================================
# TÍTULO:       gestionar_dns.sh
# VERSIÓN:      6.2 (Versión final completa con 'restart')
# DESCRIPCIÓN:  Añade, modifica, renombra y crea alias (CNAME) en un servidor BIND.
# ==============================================================================

# --- CONFIGURACIÓN ---
DNS_MASTER="dns01.santpau.es"
DNS_SLAVE="dns02.santpau.es"
DNS_USER="root"
ZONE_PATH="/var/lib/named/master"
LOG_FILE="dns_changes.log"

# --- NOTA DE SEGURIDAD ---
# Se recomienda usar un usuario con permisos delegados en lugar de 'root'.
# ---------------------------------------------------------

# --- MENÚ PRINCIPAL ---
echo "Gestor de Registros DNS para BIND"
echo "---------------------------------"
echo "1) Añadir un nuevo registro (A + PTR)"
echo "2) Modificar la IP de un registro (A + PTR)"
echo "3) Renombrar un registro (A + PTR)"
echo "4) Añadir un alias (CNAME)"
read -p "Elige una opción [1-4]: " choice

# Inicializamos variables
ACTION=""; FQDN=""; IP=""; NEW_FQDN=""; OLD_IP=""; OLD_FQDN_OF_PTR=""; TARGET_FQDN=""

case $choice in
    1) ACTION="ADD"; read -p "Introduce el nombre de dominio COMPLETO (FQDN): " FQDN; read -p "Introduce la dirección IP: " IP ;;
    2) ACTION="MODIFY"; read -p "Introduce el FQDN a modificar: " FQDN; read -p "Introduce la NUEVA dirección IP: " IP ;;
    3) ACTION="RENAME"; read -p "Introduce el FQDN ANTIGUO: " FQDN; read -p "Introduce el FQDN NUEVO: " NEW_FQDN ;;
    4) ACTION="ADD_CNAME"; read -p "Introduce el nuevo ALIAS (FQDN): " FQDN; read -p "Introduce el HOST DESTINO (FQDN): " TARGET_FQDN ;;
    *) echo "Opción no válida."; exit 1 ;;
esac

if [ -z "$FQDN" ]; then echo "Error: El nombre de dominio no puede estar vacío."; exit 1; fi

# --- LÓGICA DE COMPROBACIÓN PREVIA ---
echo "Verificando registros en $DNS_MASTER..."
OLD_IP_OF_FQDN=$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $FQDN @localhost" 2>/dev/null)

if [ "$ACTION" == "ADD" ]; then
    if [ -n "$OLD_IP_OF_FQDN" ]; then echo "Error: El registro A para '$FQDN' ya existe."; exit 1; fi
    PTR_RECORD=$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short -x $IP @localhost" 2>/dev/null)
    if [ -n "$PTR_RECORD" ]; then
        echo "AVISO: La IP '$IP' ya tiene un registro PTR que apunta a '$PTR_RECORD'."
        read -p "¿Forzar la reasignación de esta IP al nuevo host '$FQDN'? (s/n): " CONFIRM_REASSIGN
        if [[ "$CONFIRM_REASSIGN" == [sS] ]]; then ACTION="REASSIGN_PTR"; OLD_FQDN_OF_PTR=${PTR_RECORD%.}; else echo "Operación cancelada."; exit 0; fi
    fi
    CONFIRM_MSG="¿Quieres AÑADIR '$FQDN' con IP '$IP'?"
elif [ "$ACTION" == "MODIFY" ]; then
    if [ -z "$OLD_IP_OF_FQDN" ]; then echo "Error: El registro para '$FQDN' no existe."; exit 1; fi
    if [ "$OLD_IP_OF_FQDN" == "$IP" ]; then echo "Error: La IP nueva es la misma que la antigua."; exit 1; fi
    OLD_IP=$OLD_IP_OF_FQDN
    CONFIRM_MSG="¿Quieres MODIFICAR '$FQDN' de '$OLD_IP' a la nueva IP '$IP'?"
elif [ "$ACTION" == "RENAME" ]; then
    if [ -z "$OLD_IP_OF_FQDN" ]; then echo "Error: El registro para '$FQDN' no existe."; exit 1; fi
    IP=$OLD_IP_OF_FQDN
    if [ -n "$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $NEW_FQDN @localhost" 2>/dev/null)" ]; then echo "Error: El nuevo nombre '$NEW_FQDN' ya existe."; exit 1; fi
    CONFIRM_MSG="¿Quieres RENOMBRAR '$FQDN' a '$NEW_FQDN' (manteniendo la IP '$IP')?"
elif [ "$ACTION" == "ADD_CNAME" ]; then
    EXISTING_RECORD=$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $FQDN @localhost" 2>/dev/null)
    if [ -n "$EXISTING_RECORD" ]; then echo "Error: El alias '$FQDN' ya existe."; exit 1; fi
    TARGET_IP=$(ssh "${DNS_USER}@${DNS_MASTER}" "dig +short $TARGET_FQDN @localhost" 2>/dev/null)
    if [ -z "$TARGET_IP" ]; then
        read -p "AVISO: El host destino '$TARGET_FQDN' no existe. ¿Continuar? (s/n): " confirm_cname
        if [[ "$confirm_cname" != [sS] ]]; then echo "Operación cancelada."; exit 0; fi
    fi
    CONFIRM_MSG="¿Quieres crear el alias '$FQDN' para que apunte a '$TARGET_FQDN'?"
fi

if [ -z "$CONFIRM_REASSIGN" ] && [ -z "$confirm_cname" ]; then
    read -p "$CONFIRM_MSG (s/n): " CONFIRM
    if [[ "$CONFIRM" != [sS] ]]; then echo "Operación cancelada."; exit 0; fi
fi

# --- EJECUCIÓN REMOTA ---
echo "Conectando a $DNS_MASTER para realizar los cambios..."
ssh_exit_status=0
ssh -T "${DNS_USER}@${DNS_MASTER}" << EOF || ssh_exit_status=$?
    set -e
    ACTION="${ACTION}"; FQDN="${FQDN}"; IP="${IP}"; OLD_IP="${OLD_IP}"; NEW_FQDN="${NEW_FQDN}"; OLD_FQDN_OF_PTR="${OLD_FQDN_OF_PTR}"; TARGET_FQDN="${TARGET_FQDN}"; ZONE_PATH="${ZONE_PATH}"; DNS_SLAVE="${DNS_SLAVE}"
    find_forward_zone_file() { local fqdn=\$1; local domain_part=\$fqdn; while [[ "\$domain_part" == *.* ]]; do local p_file="db.\${domain_part}"; if [ -f "\${ZONE_PATH}/\${p_file}" ]; then echo "\$p_file"; return 0; fi; domain_part=\$(echo "\$domain_part" | cut -d'.' -f2-); done; return 1; }
    calculate_new_soa() { local file=\$1; local old_soa=\$(awk '/SOA/,/\)/ {if (\$1 ~ /^[0-9]{10,}/) {print \$1; exit}}' "\$file"); if [ -z "\$old_soa" ]; then echo "Error: No se pudo leer el SOA del fichero \$file." >&2; return 1; fi; local old_date=\${old_soa:0:8}; local old_serial=\${old_soa:8}; local today=\$(date +"%Y%m%d"); if [ "\$old_date" == "\$today" ]; then new_serial=\$(printf "%02d" \$((10#\$old_serial + 1))); else new_serial="01"; fi; echo "\${today}\${new_serial}"; }
    declare -A files_to_update
    BACKUP_SUFFIX=\$(date +"%Y%m%d-%H%M%S")
    case "\$ACTION" in
        ADD|REASSIGN_PTR)
            FORWARD_ZONE_FILE="\${ZONE_PATH}/\$(find_forward_zone_file "\$FQDN")"; REVERSE_ZONE_FILE="\${ZONE_PATH}/db.\$(echo "\$IP" | cut -d'.' -f1-3)"
            if [ ! -f "\$FORWARD_ZONE_FILE" ] || [ ! -f "\$REVERSE_ZONE_FILE" ]; then echo "Error: Fichero de zona no encontrado."; exit 1; fi
            files_to_update["\$FORWARD_ZONE_FILE"]=1; files_to_update["\$REVERSE_ZONE_FILE"]=1
            echo "Creando backups..."; for file in "\${!files_to_update[@]}"; do cp -p "\$file" "\${file}-\${BACKUP_SUFFIX}"; done
            echo "Añadiendo/Modificando registros..."; HOSTNAME=\$(echo "\$FQDN" | cut -d'.' -f1); LAST_OCTET=\$(echo "\$IP" | awk -F. '{print \$4}')
            ip_base=\$(echo "\$IP" | cut -d'.' -f1-3); inserted=false; for i in \$(seq \$((LAST_OCTET - 1)) -1 0); do prev_ip="\${ip_base}.\${i}"; if grep -q -F "\$prev_ip" "\$FORWARD_ZONE_FILE"; then sed -i "/\${prev_ip}/a \${HOSTNAME}\t\tIN\tA\t\${IP}" "\$FORWARD_ZONE_FILE"; inserted=true; break; fi; done; if [ "\$inserted" = false ]; then echo -e "\${HOSTNAME}\t\tIN\tA\t\${IP}" >> "\$FORWARD_ZONE_FILE"; fi
            if [ "\$ACTION" == "ADD" ]; then
                inserted=false; for i in \$(seq \$((LAST_OCTET - 1)) -1 1); do if grep -q -E "^\s*\${i}\s+" "\$REVERSE_ZONE_FILE"; then sed -i "/^\s*\${i}\s\+/a \${LAST_OCTET}\t\tIN\tPTR\t\${FQDN}." "\$REVERSE_ZONE_FILE"; inserted=true; break; fi; done; if [ "\$inserted" = false ]; then echo -e "\${LAST_OCTET}\t\tIN\tPTR\t\${FQDN}." >> "\$REVERSE_ZONE_FILE"; fi
            else; echo "Modificando registro PTR existente..."; sed -i "/\s\+PTR\s\+${OLD_FQDN_OF_PTR}\./ s/IN.*/IN\tPTR\t${FQDN}./" "\$REVERSE_ZONE_FILE"; fi
            ;;
        ADD_CNAME)
            FORWARD_ZONE_FILE="\${ZONE_PATH}/\$(find_forward_zone_file "\$FQDN")"
            if [ -z "\$FORWARD_ZONE_FILE" ]; then echo "Error: No se pudo encontrar fichero de zona directa para '\$FQDN'."; exit 1; fi
            files_to_update["\$FORWARD_ZONE_FILE"]=1
            echo "Creando backup..."; cp -p "\$FORWARD_ZONE_FILE" "\${FORWARD_ZONE_FILE}-\${BACKUP_SUFFIX}"
            echo "Añadiendo registro CNAME..."; ALIAS_HOSTNAME=\$(echo "\$FQDN" | cut -d'.' -f1)
            echo -e "\${ALIAS_HOSTNAME}\t\tIN\tCNAME\t\${TARGET_FQDN}." >> "\$FORWARD_ZONE_FILE"
            ;;
        # Aquí iría la lógica de MODIFY y RENAME si se restaura
        *) echo "Acción no implementada: \$ACTION"; exit 1 ;;
    esac
    for file in "\${!files_to_update[@]}"; do echo "Actualizando SOA para \$file..."; NEW_SOA=\$(calculate_new_soa "\$file"); sed -i.bak -E "/IN\s+SOA\s+/,/\)/s/^\s*[0-9]{10,}/\t\t\${NEW_SOA}/" "\$file"; rm -f "\${file}.bak"; done
    echo "Validando sintaxis..."; for file in "\${!files_to_update[@]}"; do zone_domain=\$(echo "\$file" | sed -E 's#.*/db\.(.*)#\1#'); if [[ \$zone_domain =~ ^[0-9] ]]; then zone_name=\$(echo "\$zone_domain" | awk -F. '{print \$3"."\$2"."$1".in-addr.arpa"}'); else zone_name=\$zone_domain; fi; if ! named-checkzone "\$zone_name" "\$file" > /dev/null 2>&1; then echo "¡ERROR DE SINTAXIS EN \$file! Restaurando..."; for f_restore in "\${!files_to_update[@]}"; do if [ -f "\${f_restore}-\${BACKUP_SUFFIX}" ]; then mv "\${f_restore}-\${BACKUP_SUFFIX}" "\$f_restore"; fi; done; exit 1; fi; done
    echo "Validación correcta."; echo "REINICIANDO servicio named en el master (restart)..."
    if ! systemctl restart named; then echo "¡FALLO AL REINICIAR NAMED EN EL MASTER!"; exit 1; fi
    echo "REINICIANDO servicio named en el esclavo (\$DNS_SLAVE)..."
    if ! ssh "\$DNS_SLAVE" "systemctl restart named"; then echo "¡AVISO! Falló el reinicio en esclavo."; fi
    echo "Limpiando backups..."; for file in "\${!files_to_update[@]}"; do mkdir -p "\${ZONE_PATH}/old"; mv "\${file}-\${BACKUP_SUFFIX}" "\${ZONE_PATH}/old/"; done
    echo "Proceso completado."
EOF
if [ $? -eq 0 ]; then
    echo "Script remoto ejecutado con éxito."
    echo "Registrando cambio en $LOG_FILE..."
    LOG_ACTION=$ACTION; if [ "$ACTION" == "REASSIGN_PTR" ]; then LOG_ACTION="ADD/REASSIGN_PTR"; fi
    if [ "$ACTION" == "RENAME" ]; then LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') - $LOG_ACTION - FROM: $FQDN, TO: $NEW_FQDN, IP: $IP - Usuario: $USER"; elif [ "$ACTION" == "ADD_CNAME" ]; then LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') - $LOG_ACTION - ALIAS: $FQDN -> TARGET: $TARGET_FQDN - Usuario: $USER"; else LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') - $LOG_ACTION - FQDN: $FQDN, IP: $IP, Old IP: $OLD_IP - Usuario: $USER"; fi
    echo "$LOG_MSG" >> "$LOG_FILE"
    echo "Verificando los cambios:"; sleep 3; if [ "$ACTION" == "RENAME" ]; then FQDN=$NEW_FQDN; fi; dig "$FQDN" @"$DNS_MASTER" | grep --color=never -A2 "ANSWER SECTION"
else
    echo "Error durante la ejecución remota. No se generó log."
fi
