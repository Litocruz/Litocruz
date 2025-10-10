#!/bin/bash

# Este script se encarga de renombrar los archivos de certificado descargados
# y de generar el certificado .pfx.
# Se espera que se ejecute después de descargar los archivos de HARICA
# en el directorio del año correspondiente.

DOMAIN_NAME=""

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

FILE_NAME=$(echo "$DOMAIN_NAME" | sed 's/\./_/g')
YEAR=$(date +%Y)
BASE_DIR="/home/jestebanl/certificadosSSL"
DOMAIN_DIR="$BASE_DIR/$FILE_NAME"
CERT_DIR="$DOMAIN_DIR/$YEAR"
PASS_FILE="$DOMAIN_DIR/passpfx.txt"
KEY_FILE="$DOMAIN_DIR/$FILE_NAME.key"

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

# Navegar al directorio de certificados para facilitar el renombramiento
cd "$CERT_DIR" || exit 1
echo "Se eliminan los posibles archivos generados en la descarga"
rm -rf *.Identifier

# Renombrar los archivos descargados de forma más robusta
echo "Renombrando los archivos de certificado..."

for file in *; do
    case "$file" in
        *bundle.pem)
            mv "$file" "${FILE_NAME}_bundle.pem"
            ;;
        *chain.p7b)
            mv "$file" "${FILE_NAME}_chain.p7b"
            ;;
        *binary.cer)
            mv "$file" "${FILE_NAME}_binary.cer"
            ;;
        *Issuer.cer)
            mv "$file" "${FILE_NAME}_Issuer.cer"
            ;;
        *.pem)
            # This must be the main .pem file
            mv "$file" "${FILE_NAME}.pem"
            ;;
        *)
            # Ignore other files
            ;;
    esac
done

# Check if the renaming was successful for all expected files
if [ ! -f "${FILE_NAME}.pem" ] || \
   [ ! -f "${FILE_NAME}_bundle.pem" ] || \
   [ ! -f "${FILE_NAME}_chain.p7b" ] || \
   [ ! -f "${FILE_NAME}_binary.cer" ] || \
   [ ! -f "${FILE_NAME}_Issuer.cer" ]; then
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
openssl pkcs12 -export -out "$FILE_NAME.pfx" -inkey "$KEY_FILE" -in "$FILE_NAME.pem" -passout file:"$PASS_FILE"

if [ $? -eq 0 ]; then
    echo "¡Certificado .pfx generado con éxito!"
    echo "El archivo .pfx se ha guardado en: $CERT_DIR/$FILE_NAME.pfx"
    echo "La contraseña para este archivo se encuentra en: $PASS_FILE"
else
    echo "Error al generar el archivo .pfx. Verifique que los archivos .pem y .key existan y sean correctos."
    exit 1
fi
