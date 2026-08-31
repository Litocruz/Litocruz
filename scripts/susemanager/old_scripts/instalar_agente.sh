#!/bin/bash

# --- Configuración ---
# El servidor de SUSE Manager ya está definido y no se preguntará.
SUSE_MANAGER_SERVER="susemanager01.santpau.es"
# ---------------------

# Colores para la salida
VERDE='\033[0;32m'
ROJO='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color

# Función para realizar comprobaciones previas
pre_flight_checks() {
    echo -e "\n${CYAN}--- Realizando comprobaciones previas ---${NC}"
    local all_ok=true

    # 1. Comprobar conectividad con el servidor SUSE Manager
    echo "1. Verificando conectividad con ${SUSE_MANAGER_SERVER}..."
    if curl -s --head "http://${SUSE_MANAGER_SERVER}" | head -n 1 | grep "200 OK" > /dev/null; then
        echo -e "   ${VERDE}OK:${NC} Se puede conectar al servidor SUSE Manager."
    else
        echo -e "   ${ROJO}ERROR:${NC} No se pudo conectar a http://${SUSE_MANAGER_SERVER}. Verifica la red y el DNS."
        all_ok=false
    fi

    # 2. Comprobar que el servicio SSH esté activo
    echo "2. Verificando que el servicio SSH (sshd) esté activo..."
    if systemctl is-active --quiet sshd; then
        echo -e "   ${VERDE}OK:${NC} El servicio SSH está corriendo."
    else
        echo -e "   ${ROJO}ERROR:${NC} El servicio SSH no está activo. El método GUI no podrá conectar."
        all_ok=false
    fi
    
    # 3. Comprobar si se ejecuta con sudo
    if [ "$EUID" -ne 0 ]; then
      echo "3. Comprobando privilegios..."
      echo -e "   ${CYAN}AVISO:${NC} Este script necesita permisos de root para la opción CLI. Asegúrate de ejecutarlo con 'sudo' si eliges esa opción."
    fi

    if [ "$all_ok" = false ]; then
        echo -e "\n${ROJO}Algunas comprobaciones fallaron. Por favor, revisa los errores antes de continuar.${NC}"
        return 1
    else
        echo -e "${VERDE}Todas las comprobaciones han pasado con éxito.${NC}"
        return 0
    fi
}

# Función para mostrar las instrucciones de la GUI
mostrar_instrucciones_gui() {
    pre_flight_checks
    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo -e "\n${VERDE}--- Instrucciones para registrar el sistema desde la GUI de SUSE Manager ---${NC}"
    echo "1. Abre tu navegador web y ve a: ${CYAN}https://susemanager01.santpau.es${NC}"
    echo "2. En el menú de la izquierda, navega a ${CYAN}Systems > Bootstrapping${NC}."
    echo "3. Rellena los siguientes campos:"
    echo -e "   - ${CYAN}Host:${NC} La dirección IP o nombre de este servidor."
    echo -e "   - ${CYAN}User:${NC} Un usuario con permisos de root (ej. 'root')."
    echo -e "   - ${CYAN}Password:${NC} La contraseña de ese usuario."
    echo -e "   - ${CYAN}Activation Key:${NC} ¡Muy importante! Selecciona la clave de activación correcta."
    echo "4. Haz clic en el botón ${CYAN}+ Bootstrap${NC}."
    echo -e "\n${VERDE}El sistema está listo. Sigue los pasos en la interfaz web.${NC}\n"
}

# Función para ejecutar la instalación desde la CLI
ejecutar_instalacion_cli() {
    pre_flight_checks
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    if [ "$EUID" -ne 0 ]; then
      echo -e "\n${ROJO}Error: La instalación vía CLI requiere privilegios de root. Por favor, ejecuta el script con 'sudo'.${NC}"
      exit 1
    fi

    echo -e "\n${VERDE}--- Iniciando instalación del agente desde la CLI ---${NC}"
    read -p "Introduce la Clave de Activación (Activation Key) para esta máquina: " activation_key

    if [ -z "$activation_key" ]; then
        echo -e "${ROJO}Error: La Clave de Activación no puede estar vacía.${NC}"
        exit 1
    fi

    BOOTSTRAP_URL="https://${SUSE_MANAGER_SERVER}/pub/bootstrap/bootstrap.sh"
    echo "Descargando script desde ${BOOTSTRAP_URL}..."

    if curl -Sks "$BOOTSTRAP_URL" -o bootstrap.sh; then
        echo "Script descargado con éxito."
    else
        echo -e "${ROJO}Error: No se pudo descargar el script. Verifica la conexión con ${SUSE_MANAGER_SERVER}.${NC}"
        exit 1
    fi

    echo "Ejecutando script de bootstrap con la clave: ${activation_key}..."
    chmod +x bootstrap.sh
    
    ./bootstrap.sh -a "$activation_key"

    if [ $? -eq 0 ]; then
        echo -e "\n${VERDE}¡Proceso de bootstrap completado!${NC}"
        echo "Por favor, ve a la GUI de SUSE Manager (Salt > Keys) para aceptar la nueva llave."
    else
        echo -e "\n${ROJO}Error: El script de bootstrap falló. Revisa la salida para más detalles.${NC}"
    fi
    
    rm bootstrap.sh
}

# --- Menú Principal ---
echo "Este script preparará y registrará este sistema en SUSE Manager."
echo "Servidor SUSE Manager configurado: ${CYAN}${SUSE_MANAGER_SERVER}${NC}"
echo ""
echo "¿Cómo deseas proceder?"
PS3="Por favor, elige una opción: "
options=("Registrar via GUI (Realizar comprobaciones y mostrar instrucciones)" "Registrar via CLI (Realizar comprobaciones y ejecutar ahora)" "Salir")
select opt in "${options[@]}"
do
    case $opt in
        "Registrar via GUI (Realizar comprobaciones y mostrar instrucciones)")
            mostrar_instrucciones_gui
            break
            ;;
        "Registrar via CLI (Realizar comprobaciones y ejecutar ahora)")
            ejecutar_instalacion_cli
            break
            ;;
        "Salir")
            break
            ;;
        *) echo "Opción inválida $REPLY";;
    esac
done
