#!/bin/bash

# Script de prueba para validar la copia de archivos a la unidad de red.

DOMAIN_NAME="prueba.test.com"
FILE_NAME=$(echo "$DOMAIN_NAME" | sed 's/\./_/g')
BASE_DIR="$(pwd)"
DOMAIN_DIR="$BASE_DIR/$FILE_NAME"
YEAR=$(date +%Y)

NETWORK_PATH="//fs02u02/U/CarpInformatica_Sistemes_Outsourcing_Seguretat/scripts"
NETWORK_PATH_CYGWIN=$(cygpath -u "$NETWORK_PATH") # Conversión necesaria para cp

echo "--------------------------------------------------------"
echo "INICIANDO PRUEBA DE COPIA A UNIDAD DE RED"
echo "Directorio de prueba a copiar: $DOMAIN_DIR"
echo "Ruta de red destino (Cygwin): $NETWORK_PATH_CYGWIN"
echo "--------------------------------------------------------"

# Simular la existencia del directorio de trabajo
if [ ! -d "$DOMAIN_DIR" ]; then
    echo "Creando directorio temporal de prueba: $DOMAIN_DIR"
    mkdir -p "$DOMAIN_DIR/$YEAR"
    echo "Este es un archivo de prueba." > "$DOMAIN_DIR/archivo_prueba.txt"
fi

# --------------------------------------------------------------------------------
# Lógica de Copia a Ruta de Red
# --------------------------------------------------------------------------------

read -r -p "¿Desea copiar el directorio '$FILE_NAME' de prueba a la ruta de red? (s/n): " COPY_RESPONSE

if [[ "$COPY_RESPONSE" =~ ^[Ss]$ ]]; then
    echo "Copiando $FILE_NAME a $NETWORK_PATH..."
    
    # Se usa el nombre del subdirectorio (FILE_NAME) como origen y el path cygwin como destino
    # Esto copiará el directorio completo (ej: 'prueba_test_com') al destino.
    cp -r "$FILE_NAME" "$NETWORK_PATH_CYGWIN/"
    
    if [ $? -eq 0 ]; then
        echo "RESULTADO: ÉXITO. Copia finalizada. Verifique: $NETWORK_PATH/$FILE_NAME"
    else
        echo "RESULTADO: FALLO. ERROR al copiar el directorio a la ruta de red."
        echo "Verifique: 1. Permisos de acceso. 2. Si la ruta UNC es accesible desde Cygwin."
    fi
    
    # Limpieza: eliminar el directorio de prueba
    rm -rf "$DOMAIN_DIR"
else
    echo "Copia a la ruta de red omitida por el usuario. Limpiando archivos de prueba."
    rm -rf "$DOMAIN_DIR"
fi

echo "--------------------------------------------------------"
