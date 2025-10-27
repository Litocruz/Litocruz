#!/bin/bash

# Script de prueba para validar la funcionalidad de envío de correo en Cygwin.

DOMAIN_NAME="prueba.test.com"
FILE_NAME=$(echo "$DOMAIN_NAME" | sed 's/\./_/g')

echo "--------------------------------------------------------"
echo "INICIANDO PRUEBA DE ENVÍO DE CORREO"
echo "Dominio de prueba: $DOMAIN_NAME"
echo "--------------------------------------------------------"

# --------------------------------------------------------------------------------
# Lógica de Envío de Correo Electrónico
# --------------------------------------------------------------------------------

read -r -p "¿Desea enviar el correo de prueba a Nagios/LHSP? (s/n): " MAIL_RESPONSE

if [[ "$MAIL_RESPONSE" =~ ^[Ss]$ ]]; then
    # Se genera el cuerpo del correo
    EMAIL_SUBJECT="[PRUEBA] Generacion nuevo certificado $DOMAIN_NAME"
    EMAIL_BODY="Hola,\n\nSe solicita monitorizar el certificado de referencia y poner debajo el nombre de dominio.\n\n$DOMAIN_NAME\n\nMuchas gracias"
    
    echo "Intentando enviar correo..."

    # Se usa 'sendmail' que es el comando estándar para Cygwin/Linux.
    (
        echo "Subject: $EMAIL_SUBJECT"
        echo "To: julianesteban.lamadrid@es.logicalis.com"
        echo "Content-Type: text/plain; charset=\"UTF-8\""
        echo ""
        echo -e "$EMAIL_BODY"
    ) | sendmail -t 

    if [ $? -eq 0 ]; then
        echo "RESULTADO: ÉXITO. Correo de prueba enviado con éxito a los destinatarios."
        echo "Asunto: $EMAIL_SUBJECT"
    else
        echo "RESULTADO: FALLO. ADVERTENCIA: Falló el envío del correo. Verifique la configuración de 'sendmail' en Cygwin."
    fi
else
    echo "Envío de correo electrónico omitido por el usuario."
fi

echo "--------------------------------------------------------"
