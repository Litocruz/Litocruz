#!/bin/bash

# Este script automatiza la generación de archivos .cnf, .csr y .key.

TEMPLATE_CNF="template.cnf"
DOMAIN_NAME=""
# Definir el directorio base como el directorio actual de ejecución
BASE_DIR="$(pwd)"

# Función para mostrar el uso del script
mostrar_ayuda() {
    echo "Uso: $0 -d <nombre_de_dominio>"
    echo ""
    echo "Opciones:"
    echo "  -d <nombre_de_dominio>  El nombre de dominio para el certificado (ej. test.santpau.es)"
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
    echo "Asegúrese de que el archivo exista en este directorio y tenga el nombre exacto."
    exit 1
fi

echo "Iniciando la generación de archivos para el dominio: $DOMAIN_NAME"

# Definición de variables
FILE_NAME=$(echo "$DOMAIN_NAME" | sed 's/\./_/g')
YEAR=$(date +%Y)
DOMAIN_DIR="$BASE_DIR/$FILE_NAME"
CERT_DIR="$DOMAIN_DIR/$YEAR"

# Crear la estructura de directorios
mkdir -p "$CERT_DIR"

echo "Directorio de trabajo creado: $DOMAIN_DIR"

# 1. Generar el archivo .cnf a partir del template
echo "Generando el archivo .cnf..."
NEW_CNF="$DOMAIN_DIR/$FILE_NAME.cnf"
sed "s/<FQDN>/$DOMAIN_NAME/g" "$TEMPLATE_CNF" > "$NEW_CNF"

echo "Archivo .cnf generado: $NEW_CNF"

# 2. Generar el .csr y la clave privada .key
echo "Generando el archivo .csr y la clave privada .key..."
# Se usa ruta absoluta para OpenSSL
openssl req -out "$DOMAIN_DIR/$FILE_NAME.csr" -newkey rsa:2048 -nodes -keyout "$DOMAIN_DIR/$FILE_NAME.key" -config "$NEW_CNF"

if [ $? -eq 0 ]; then
    echo "Certificado .csr y clave .key generados con éxito."
    echo "El archivo .csr se ha guardado en: $DOMAIN_DIR/$FILE_NAME.csr"
    echo "La clave privada .key se ha guardado en: $DOMAIN_DIR/$FILE_NAME.key"
else
    echo "Error al generar el .csr y .key. Abortando."
    exit 1
fi

# 3. Mostrar el contenido del .csr y copiarlo al portapapeles
echo ""
echo "=========================================================================================="
echo "  CONTENIDO DEL ARCHIVO CSR PARA COPIAR EN HARICA"
echo "=========================================================================================="
CSR_CONTENT=$(cat "$DOMAIN_DIR/$FILE_NAME.csr")
echo "$CSR_CONTENT"
echo "=========================================================================================="

# Copiar al portapapeles (para Cygwin)
if command -v xclip &> /dev/null; then
    echo "$CSR_CONTENT" | xclip -selection clipboard
    echo ""
    echo "¡El contenido del CSR ha sido copiado a su portapapeles (usando xclip)!"
    echo ""
elif command -v clip &> /dev/null; then
    echo "$CSR_CONTENT" | clip
    echo ""
    echo "¡El contenido del CSR ha sido copiado a su portapapeles (usando clip)!"
    echo ""
else
    echo "Advertencia: 'xclip' o 'clip' no está instalado. No se pudo copiar el contenido al portapapeles."
    echo "Por favor, copie manualmente el texto del CSR de arriba."
fi

echo ""
echo "******************************************************************************************"
echo "  SIGUIENTE PASO: Descargue los certificados de HARICA en el directorio:"
echo "  $CERT_DIR"
echo "******************************************************************************************"
echo ""
echo "Una vez que haya descargado los archivos, ejecute el siguiente comando para generar el .pfx:"
echo "./generar_pfx.sh -d $DOMAIN_NAME"
