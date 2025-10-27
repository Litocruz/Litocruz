#!/bin/bash

# ==============================================================================
# Script de Configuración Inicial de Máquinas Virtuales
#
# Autor: Asistente de Programación
# Versión: 4.0
#
# Descripción:
# Este script automatiza los pasos iniciales de configuración para una nueva VM,
# incluyendo red, usuarios, firewall y la instalación de agentes específicos.
# Puede ejecutarse de forma interactiva, mediante argumentos de línea de comandos
# o ejecutando tareas específicas de forma aislada.
# ==============================================================================

# --- Variables de color y funciones de log ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==============================================================================
# 1. VERIFICACIONES INICIALES
# ==============================================================================
if [[ $EUID -ne 0 ]]; then
   log_error "Este script debe ser ejecutado como root. Usa 'sudo ./config_vm.sh'."
   exit 1
fi

OS_FAMILY=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then OS_FAMILY="debian";
    elif [[ "$ID" == "centos" || "$ID" == "rhel" || "$ID" == "rocky" ]]; then OS_FAMILY="rhel";
    elif [[ "$ID" == "sles" ]]; then OS_FAMILY="sles"; fi
else
    log_error "No se pudo detectar el sistema operativo."; exit 1
fi
log_info "Sistema operativo detectado: $NAME ($OS_FAMILY)"

# ==============================================================================
# 2. FUNCIONES DE TAREAS
# ==============================================================================

configure_network() {
    log_info "Iniciando configuración de red..."
    [[ -z "$IP_ADDR" ]] && read -p "Introduce la dirección IP: " IP_ADDR
    [[ -z "$NETMASK" ]] && read -p "Introduce la máscara de red (ej. 24): " NETMASK
    [[ -z "$GATEWAY" ]] && read -p "Introduce la puerta de enlace (Gateway): " GATEWAY
    [[ -z "$DNS" ]] && read -p "Introduce el servidor DNS: " DNS
    INTERFACE=$(ip route | awk '/^default/ {print $5; exit}')
    log_info "Configurando la interfaz '$INTERFACE'..."
    if [[ "$OS_FAMILY" == "rhel" || "$OS_FAMILY" == "sles" ]]; then
        nmcli con mod "$INTERFACE" ipv4.method manual ipv4.addresses "$IP_ADDR/$NETMASK" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS" && nmcli con up "$INTERFACE"
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        echo -e "network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    $INTERFACE:\n      addresses:\n        - $IP_ADDR/$NETMASK\n      gateway4: $GATEWAY\n      nameservers:\n        addresses: [$DNS]" > /etc/netplan/01-custom-netcfg.yaml && netplan apply
    else
        log_error "La configuración de red no está soportada para este SO."; return 1
    fi
    if [ $? -eq 0 ]; then log_info "Red configurada correctamente."; else log_error "Falló la configuración de red."; return 1; fi
}

create_user() {
    log_info "Iniciando creación de usuario..."
    [[ -z "$NEW_USER" ]] && read -p "Introduce el nombre del nuevo usuario: " NEW_USER
    [[ -z "$NEW_PASS" ]] && read -s -p "Introduce la contraseña para '$NEW_USER': " NEW_PASS && echo ""
    if id "$NEW_USER" &>/dev/null; then log_warn "El usuario '$NEW_USER' ya existe."; return 0; fi
    useradd -m -s /bin/bash "$NEW_USER" && echo "$NEW_USER:$NEW_PASS" | chpasswd
    log_info "Usuario '$NEW_USER' creado."
    if [[ -z "$ADD_SUDO" ]]; then read -p "¿Deseas dar permisos de sudo a este usuario? (s/n): " ADD_SUDO; fi
    if [[ "$ADD_SUDO" =~ ^[Ss]$ ]]; then
        local sudo_group=$([[ "$OS_FAMILY" == "debian" ]] && echo "sudo" || echo "wheel")
        usermod -aG "$sudo_group" "$NEW_USER" && log_info "Usuario '$NEW_USER' añadido al grupo '$sudo_group'."
    fi
}

disable_firewall() {
    log_info "Desactivando el firewall..."
    if [[ "$OS_FAMILY" == "debian" ]] && systemctl is-active --quiet ufw; then
        systemctl stop ufw && systemctl disable ufw && log_info "Firewall 'ufw' desactivado."
    elif [[ "$OS_FAMILY" == "rhel" || "$OS_FAMILY" == "sles" ]] && systemctl is-active --quiet firewalld; then
        systemctl stop firewalld && systemctl disable firewalld && log_info "Firewall 'firewalld' desactivado."
    else
        log_warn "El firewall no estaba activo."
    fi
}

configure_lvm() {
    read -p "¿Deseas configurar discos LVM ahora? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then log_warn "La funcionalidad LVM aún no está implementada."; fi
}

configure_swap() {
    read -p "¿Deseas configurar memoria SWAP ahora? (s/n): " choice
    if [[ "$choice" =~ ^[Ss]$ ]]; then log_warn "La funcionalidad SWAP aún no está implementada."; fi
}

check_vmware_tools() {
    log_info "Verificando estado de VMware Tools..."
    if systemctl is-active --quiet vmtoolsd; then log_info "VMware Tools (vmtoolsd) está instalado y en ejecución.";
    else log_warn "VMware Tools (vmtoolsd) no parece estar en ejecución."; fi
}

install_ds_agent() {
    local script_name="ds-agent-instalation-script.sh"
    log_info "Buscando el script de instalación de Deep Security..."
    if [ -f "./$script_name" ]; then
        log_info "Script encontrado. Ejecutando..."
        chmod +x "./$script_name" && ./"$script_name"
        if [ $? -eq 0 ]; then log_info "Script de Deep Security ejecutado."; else log_error "El script de Deep Security finalizó con error."; fi
    else
        log_warn "No se encontró el script './$script_name'. Omitiendo instalación."
    fi
}

install_suse_manager_agent() {
    if [[ "$OS_FAMILY" != "sles" ]]; then log_info "El sistema no es SLES. Omitiendo."; return 0; fi
    log_info "Iniciando configuración del agente de SUSE Manager..."
    log_info "Paso 1/4: Preparando la máquina (limpieza de repos, SCC y machine-id)..."
    if [ ! -d /etc/zypp/repos.d.old ]; then mkdir -p /etc/zypp/repos.d.old; fi
    if [ -n "$(ls -A /etc/zypp/repos.d/)" ]; then mv /etc/zypp/repos.d/* /etc/zypp/repos.d.old/; fi
    zypper --non-interactive verify >/dev/null 2>&1
    if command -v SUSEConnect &> /dev/null; then SUSEConnect --cleanup >/dev/null 2>&1; fi
    if systemctl is-active --quiet salt-minion; then systemctl stop salt-minion; fi
    rm -f /etc/machine-id /var/lib/dbus/machine-id; rm -rf /var/cache/salt
    dbus-uuidgen --ensure; systemd-machine-id-setup
    log_info "Preparación finalizada."
    log_info "Paso 2/4: Obteniendo scripts de registro..."
    read -p "Introduce la dirección del servidor SUSE Manager: " SUSE_MANAGER_SERVER
    if [[ -z "$SUSE_MANAGER_SERVER" ]]; then log_error "La dirección del servidor es necesaria. Abortando."; return 1; fi
    ALL_SCRIPTS=$(curl -s "http://${SUSE_MANAGER_SERVER}/pub/bootstrap/" | grep -o 'href="[^"]*\.sh"' | sed -e 's/href="//' -e 's/"//')
    if [[ -z "$ALL_SCRIPTS" ]]; then
        log_error "No se pudieron obtener los scripts del servidor. Se procederá con la introducción manual."
        read -p "Introduce el nombre COMPLETO del script bootstrap: " BOOTSTRAP_SCRIPT_NAME
    else
        . /etc/os-release
        SLES_MAJOR_VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1)
        mapfile -t MATCHING_SCRIPTS < <(echo "$ALL_SCRIPTS" | grep -E "sles${SLES_MAJOR_VERSION}|sle${SLES_MAJOR_VERSION}")
        if [ ${#MATCHING_SCRIPTS[@]} -eq 0 ]; then
            log_warn "No se encontraron scripts para SLES v${SLES_MAJOR_VERSION}. Mostrando todos los scripts."
            mapfile -t MATCHING_SCRIPTS < <(echo "$ALL_SCRIPTS")
        fi
        log_info "Por favor, selecciona el script de bootstrap adecuado:"
        PS3="Elige una opción (número): "
        select script_choice in "${MATCHING_SCRIPTS[@]}"; do
            if [[ -n "$script_choice" ]]; then BOOTSTRAP_SCRIPT_NAME="$script_choice"; break;
            else log_error "Opción no válida."; fi
        done
    fi
    if [[ -z "$BOOTSTRAP_SCRIPT_NAME" ]]; then log_error "No se seleccionó script. Abortando."; return 1; fi
    local bootstrap_url="http://${SUSE_MANAGER_SERVER}/pub/bootstrap/${BOOTSTRAP_SCRIPT_NAME}"
    log_info "Paso 3/4: Ejecutando script: $BOOTSTRAP_SCRIPT_NAME"
    curl -Sks "${bootstrap_url}" -o "/tmp/bootstrap.sh"
    if [ $? -eq 0 ]; then
        sh /tmp/bootstrap.sh
        if [ $? -ne 0 ]; then log_error "El script de bootstrap finalizó con error."; return 1; fi
        log_info "Paso 4/4: Refrescando repositorios..."
        zypper lr && zypper --non-interactive ref -s
        log_info "¡Proceso de registro en SUSE Manager completado!"
    else
        log_error "No se pudo descargar el script de bootstrap."; return 1
    fi
}

# ==============================================================================
# 3. PROCESAMIENTO DE ARGUMENTOS Y EJECUCIÓN
# ==============================================================================

show_help() {
    echo -e "${GREEN}Uso: $0 [opciones de datos] [opciones de ejecución]${NC}"
    echo ""
    echo "Descripción:"
    echo "  Este script configura una VM de forma interactiva o automatizada."
    echo "  - Si se ejecuta sin argumentos, inicia el modo interactivo completo."
    echo "  - Si se usa una opción '--do-<tarea>', solo se ejecuta esa tarea."
    echo ""
    echo -e "${YELLOW}Opciones de Datos (para modo automatizado):${NC}"
    echo "  --ip ADDR        Dirección IP estática."
    echo "  --netmask MASK   Máscara de red en formato CIDR (ej. 24)."
    echo "  --gateway GW     Puerta de enlace."
    echo "  --dns DNS        Servidor DNS."
    echo "  --user USER      Nombre del nuevo usuario a crear."
    echo "  --password PASS  Contraseña para el nuevo usuario."
    echo "  --sudo yes|no    Añadir el nuevo usuario a sudoers (default: no)."
    echo ""
    echo -e "${YELLOW}Opciones de Ejecución Selectiva:${NC}"
    echo "  --do-network         Ejecuta solo la configuración de red."
    echo "  --do-user            Ejecuta solo la creación de usuario."
    echo "  --do-firewall        Ejecuta solo la desactivación del firewall."
    echo "  --do-lvm             Ejecuta solo la configuración LVM (plantilla)."
    echo "  --do-swap            Ejecuta solo la configuración SWAP (plantilla)."
    echo "  --do-vmtools         Ejecuta solo la verificación de VMware Tools."
    echo "  --do-dsagent         Ejecuta solo la instalación del agente de Deep Security."
    echo "  --do-susemanager     Ejecuta solo la configuración del agente de SUSE Manager."
    echo "  -h, --help           Muestra esta ayuda."
}

EXEC_MODE="all"
declare -A TASKS_TO_RUN

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ip) IP_ADDR="$2"; shift ;;
        --netmask) NETMASK="$2"; shift ;;
        --gateway) GATEWAY="$2"; shift ;;
        --dns) DNS="$2"; shift ;;
        --user) NEW_USER="$2"; shift ;;
        --password) NEW_PASS="$2"; shift ;;
        --sudo) ADD_SUDO="$2"; shift ;;
        --do-network)     EXEC_MODE="selective"; TASKS_TO_RUN[network]=1 ;;
        --do-user)        EXEC_MODE="selective"; TASKS_TO_RUN[user]=1 ;;
        --do-firewall)    EXEC_MODE="selective"; TASKS_TO_RUN[firewall]=1 ;;
        --do-lvm)         EXEC_MODE="selective"; TASKS_TO_RUN[lvm]=1 ;;
        --do-swap)        EXEC_MODE="selective"; TASKS_TO_RUN[swap]=1 ;;
        --do-vmtools)     EXEC_MODE="selective"; TASKS_TO_RUN[vmtools]=1 ;;
        --do-dsagent)     EXEC_MODE="selective"; TASKS_TO_RUN[dsagent]=1 ;;
        --do-susemanager) EXEC_MODE="selective"; TASKS_TO_RUN[susemanager]=1 ;;
        -h|--help) show_help; exit 0 ;;
        *) log_error "Opción desconocida: $1"; show_help; exit 1 ;;
    esac
    shift
done

if [[ -n "$IP_ADDR" || -n "$NEW_USER" ]]; then EXEC_MODE="selective"; fi
if [[ -n "$IP_ADDR" ]]; then TASKS_TO_RUN[network]=1; fi
if [[ -n "$NEW_USER" ]]; then TASKS_TO_RUN[user]=1; fi

main() {
    log_info "=== INICIANDO SCRIPT DE CONFIGURACIÓN V4.0 ==="
    if [[ "$EXEC_MODE" == "all" ]]; then
        log_info "Modo de ejecución: Completo (Interactivo)"
        configure_network && create_user && disable_firewall && configure_lvm && \
        configure_swap && check_vmware_tools && install_ds_agent && install_suse_manager_agent
    else
        log_info "Modo de ejecución: Selectivo"
        [[ ${TASKS_TO_RUN[network]} ]]     && configure_network
        [[ ${TASKS_TO_RUN[user]} ]]        && create_user
        [[ ${TASKS_TO_RUN[firewall]} ]]    && disable_firewall
        [[ ${TASKS_TO_RUN[lvm]} ]]         && configure_lvm
        [[ ${TASKS_TO_RUN[swap]} ]]        && configure_swap
        [[ ${TASKS_TO_RUN[vmtools]} ]]     && check_vmware_tools
        [[ ${TASKS_TO_RUN[dsagent]} ]]     && install_ds_agent
        [[ ${TASKS_TO_RUN[susemanager]} ]] && install_suse_manager_agent
    fi
    log_info "=== SCRIPT FINALIZADO ==="
}

main
