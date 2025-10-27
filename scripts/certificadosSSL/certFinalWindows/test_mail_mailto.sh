#!/bin/bash

# Script de prueba para validar la funcionalidad de envío de correo (mailto) en Cygwin.

DOMAIN_NAME="prueba.test.com"
FILE_NAME=$(echo "$DOMAIN_NAME" | sed 's/\./_/g')

echo "--------------------------------------------------------"
echo "INICIANDO PRUEBA DE ENVÍO DE CORREO"
echo "Dominio de prueba: $DOMAIN_NAME"
echo "--------------------------------------------------------"

# --------------------------------------------------------------------------------
# Lógica de Envío de Correo Electrónico
# --------------------------------------------------------------------------------

read -r -p "¿Desea abrir el gestor de correo para enviar la notificación de prueba? (s/n): " MAIL_RESPONSE

if [[ "$MAIL_RESPONSE" =~ ^[Ss]$ ]]; then
    # Codificación para URL: Saltos de línea (%0D%0A), Espacios (%20)
    EMAIL_TO="administracion.nagios@es.logicalis.com"
    EMAIL_CC="LHSP@es.logicalis.com"
    EMAIL_SUBJECT="[PRUEBA] Generacion nuevo certificado $DOMAIN_NAME"
    
    # Cuerpo del correo con salto de línea codificado
    EMAIL_BODY="Hola,%0D%0A%0D%0ASe%20solicita%20monitorizar%20el%20certificado%20de%20referencia%20y%20poner%20debajo%20el%20nombre%20de%20dominio.%0D%0A%0D%0A$DOMAIN_NAME%0D%0A%0D%0AMuchas%20gracias"
    
    MAILTO_LINK="mailto:$EMAIL_TO?cc=$EMAIL_CC&subject=$EMAIL_SUBJECT&body=$EMAIL_BODY"
    
    # El comando 'start' es un comando nativo de Windows que Cygwin entiende.
    cmd /c start "" "$MAILTO_LINK"
    
    echo "Gestor de correo abierto. Por favor, revise el borrador y envíelo."
else
    echo "Envío de correo electrónico omitido por el usuario."
fi

echo "--------------------------------------------------------"
