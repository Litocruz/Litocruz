#!/bin/bash

# Este script se encarga de renombrar los archivos de certificado descargados,
# generar el .pfx, loguear la información y comprimir todo.

TEMPLATE_CNF="template.cnf"
DOMAIN_NAME=""
# Definir el directorio base como el directorio actual de ejecución
BASE_DIR="$(pwd)"

# Función para mostrar el uso del script
mostrar_ayuda() {
    echo "Uso: $0 -d <nombre_de_dominio>"
    echo ""
    echo "Opciones:"
    echo "  -d <nombre_de_dominio>  El nombre de dominio del certificado a procesar."
    exit 1
}

# Analizar los argumentos de la línea de comandos
while getopts "d:" opt; do
    case ${opt} in
        d )
            DOMAIN_NAME=$OPTARG
            ;;
        \? )
            mostrar_ayuda
            ;;
        : )
            echo "Error: La opción -$OPTARG requiere un argumento."
            mostrar_ayuda
            ;;
    esac
done

# Validar que se proporcionó un nombre de dominio
if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: Debe proporcionar un nombre de dominio."
    mostrar_ayuda
fi

# =================================================================
# VALIDACIÓN DE SEGURIDAD 1: template.cnf
# =================================================================
if [ ! -f "$TEMPLATE_CNF" ]; then
    echo "ERROR CRÍTICO: No se encontró el archivo de plantilla '$TEMPLATE_CNF'."
    echo "Asegúrese de que el archivo exista en este directorio."
    exit 1
fi

FILE_NAME=$(echo "$DOMAIN_NAME" | sed 's/\./_/g')
YEAR=$(date +%Y)
RENAMED_FILE_NAME="${FILE_NAME}_${YEAR}"
# Definición de directorios y archivos usando BASE_DIR
DOMAIN_DIR="$BASE_DIR/$FILE_NAME"
CERT_DIR="$DOMAIN_DIR/$YEAR"
PASS_FILE="$DOMAIN_DIR/passpfx.txt"
KEY_FILE="$DOMAIN_DIR/$FILE_NAME.key"
LOG_FILE="$BASE_DIR/ssl_log.txt"
ZIP_FILE="${FILE_NAME}_${YEAR}.zip"

echo "Iniciando el procesamiento de certificados para el dominio: $DOMAIN_NAME"
echo "Esperando certificados en el directorio: $CERT_DIR"

if [ ! -d "$CERT_DIR" ]; then
    echo "Error: No se encontró el directorio de certificados. Por favor, asegúrese de haber descargado los archivos en $CERT_DIR"
    exit 1
fi

# Validar la existencia de la clave privada antes de continuar
if [ ! -f "$KEY_FILE" ]; then
    echo "Error: No se encontró la clave privada en $KEY_FILE."
    echo "Asegúrese de que el script generar_cert.sh se ejecutó correctamente."
    exit 1
fi

# Renombrar los archivos descargados de forma más robusta
echo "Renombrando los archivos de certificado..."

for file in "$CERT_DIR"/*; do
    case "$file" in
        *"bundle.pem")
            mv "$file" "${CERT_DIR}/${RENAMED_FILE_NAME}_bundle.pem"
            ;;
        *"chain.p7b")
            mv "$file" "${CERT_DIR}/${RENAMED_FILE_NAME}_chain.p7b"
            ;;
        *"binary.cer")
            mv "$file" "${CERT_DIR}/${RENAMED_FILE_NAME}_binary.cer"
            ;;
        *"Issuer.cer")
            # Duplicación y renombrado del Issuer.cer
            cp "$file" "${CERT_DIR}/${RENAMED_FILE_NAME}_cert+ca.cer"
            mv "$file" "${CERT_DIR}/${RENAMED_FILE_NAME}_Issuer.cer"
            ;;
        *.pem)
            # This must be the main .pem file
            mv "$file" "${CERT_DIR}/${RENAMED_FILE_NAME}.pem"
            ;;
        *)
            # Ignore other files
            ;;
    esac
done

# Check if the renaming was successful for all expected files
if [ ! -f "${CERT_DIR}/${RENAMED_FILE_NAME}.pem" ] || \
   [ ! -f "${CERT_DIR}/${RENAMED_FILE_NAME}_bundle.pem" ] || \
   [ ! -f "${CERT_DIR}/${RENAMED_FILE_NAME}_chain.p7b" ] || \
   [ ! -f "${CERT_DIR}/${RENAMED_FILE_NAME}_binary.cer" ] || \
   [ ! -f "${CERT_DIR}/${RENAMED_FILE_NAME}_Issuer.cer" ]; then
    echo "Error al renombrar los archivos. Asegúrese de que todos los archivos esperados estén presentes y tengan los nombres correctos."
    exit 1
fi

echo "Archivos renombrados con éxito."

# Generar la contraseña aleatoria para el archivo .pfx y guardarla en un archivo
echo "Generando una contraseña aleatoria para el archivo .pfx..."
openssl rand -base64 14 > "$PASS_FILE"
echo "Contraseña guardada en: $PASS_FILE"

# Generar el certificado .pfx usando la ruta absoluta para el archivo .key
echo "Generando el archivo .pfx..."
openssl pkcs12 -export -out "${CERT_DIR}/${RENAMED_FILE_NAME}.pfx" -inkey "$KEY_FILE" -in "${CERT_DIR}/${RENAMED_FILE_NAME}.pem" -passout file:"$PASS_FILE" -name "$DOMAIN_NAME"

if [ $? -eq 0 ]; then
    echo "¡Certificado .pfx generado con éxito!"
    echo "El archivo .pfx se ha guardado en: $CERT_DIR/${RENAMED_FILE_NAME}.pfx"
    echo "La contraseña para este archivo se encuentra en: $PASS_FILE"
else
    echo "Error al generar el archivo .pfx. Verifique que los archivos .pem y .key existan y sean correctos."
    exit 1
fi

# --------------------------------------------------------------------------------
# PASO FINAL 1: GENERACIÓN DEL LOG
# --------------------------------------------------------------------------------
echo "Generando registro en el log..."

# Obtener la fecha de caducidad del certificado (se asume que el certificado principal es el que se usa)
EXPIRY_DATE=$(openssl x509 -in "${CERT_DIR}/${RENAMED_FILE_NAME}.pem" -enddate -noout | sed 's/notAfter=//')
TODAY_DATE=$(date '+%Y-%m-%d')

# Formato: Fecha de Hoy | Fecha de Caducidad | Nombre del Certificado
LOG_ENTRY="$TODAY_DATE | $EXPIRY_DATE | $DOMAIN_NAME"
echo "$LOG_ENTRY" >> "$LOG_FILE"
echo "Registro de log guardado en: $LOG_FILE"

# --------------------------------------------------------------------------------
# Eliminación de archivos *.Identifier
# --------------------------------------------------------------------------------
echo "Eliminando archivos temporales Identifier..."
rm -f "$CERT_DIR"/*.Identifier

# --------------------------------------------------------------------------------
# PASO FINAL 2: COMPRESIÓN
# --------------------------------------------------------------------------------
echo "Comprimiendo todos los archivos generados..."
# Cambiar temporalmente de directorio para asegurar estructura limpia del ZIP
cd "$BASE_DIR" || exit 1
zip -r "$ZIP_FILE" "$FILE_NAME"

if [ $? -eq 0 ]; then
    echo "¡Archivos comprimidos con éxito!"
    echo "El archivo zip se ha guardado en: $DOMAIN_DIR/$ZIP_FILE"
    
    # --------------------------------------------------------------------------------
    # Envío de Correo Electrónico (Usando cmd /c start mailto:)
    # --------------------------------------------------------------------------------
    echo ""
    read -r -p "¿Desea abrir el gestor de correo para enviar la notificación a Nagios/LHSP? (s/n): " MAIL_RESPONSE

    if [[ "$MAIL_RESPONSE" =~ ^[Ss]$ ]]; then
        # Codificación para URL: Saltos de línea (%0D%0A), Espacios (%20)
        EMAIL_TO="administracion.nagios@es.logicalis.com"
        EMAIL_CC="LHSP@es.logicalis.com"
        EMAIL_SUBJECT="Generacion nuevo certificado $DOMAIN_NAME"
        
        # Cuerpo del correo con salto de línea codificado
        EMAIL_BODY="Hola,%0D%0A%0D%0ASe%20solicita%20monitorizar%20el%20certificado%20de%20referencia%20y%20poner%20debajo%20el%20nombre%20de%20dominio.%0D%0A%0D%0A$DOMAIN_NAME%0D%0A%0D%0AMuchas%20gracias"
        
        MAILTO_LINK="mailto:$EMAIL_TO?cc=$EMAIL_CC&subject=$EMAIL_SUBJECT&body=$EMAIL_BODY"
        
        # --- CAMBIO FINAL: Uso de cmd /c start "" ---
        cmd /c start "" "$MAILTO_LINK"
        
        echo "Gestor de correo abierto. Por favor, revise el borrador y envíelo."
    else
        echo "Envío de correo electrónico omitido por el usuario."
    fi

else
    echo "Advertencia: Error al crear el archivo zip. Los archivos de certificado no se han comprimido."
fi

# --------------------------------------------------------------------------------
# PASO FINAL 3: COPIAR A RUTA DE RED
# --------------------------------------------------------------------------------
NETWORK_PATH="//fs02u02/U/CarpInformatica_Sistemes_Outsourcing_Seguretat/Certificats_SSL"
NETWORK_PATH_CYGWIN=$(cygpath -u "$NETWORK_PATH") # Convertir la ruta UNC a formato Cygwin

echo ""
read -r -p "¿Desea copiar el directorio '$FILE_NAME' (incluyendo el ZIP) a la ruta de red compartida? (s/n): " COPY_RESPONSE

if [[ "$COPY_RESPONSE" =~ ^[Ss]$ ]]; then
    # Se copia el contenido del directorio del dominio al directorio de red
    echo "Copiando $FILE_NAME a $NETWORK_PATH..."
    cp -r "$FILE_NAME" "$NETWORK_PATH_CYGWIN/"
    
    if [ $? -eq 0 ]; then
        echo "Copia finalizada con éxito. Carpeta de destino: $NETWORK_PATH"
    else
        echo "ERROR al copiar el directorio a la ruta de red. Verifique los permisos de acceso y que la ruta UNC sea correcta."
    fi
else
    echo "Copia a la ruta de red omitida por el usuario."
fi
