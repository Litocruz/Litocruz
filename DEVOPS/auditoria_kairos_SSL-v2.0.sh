#!/bin/bash

echo -e "NAMESPACE\tROUTE\tEXPIRATION\tHOST"
echo -e "---------\t-----\t----------\t----"

# 1. Auditoría de ROUTES (Buscamos todas las que tengan TLS definido)
oc get routes -A -o jsonpath='{range .items[?(@.spec.tls)]}{.metadata.namespace}{","}{.metadata.name}{","}{.spec.host}{"\n"}{end}' | while IFS="," read -r ns name host; do
    
    # Intentamos extraer el certificado de la ruta
    cert=$(oc get route "$name" -n "$ns" -o jsonpath='{.spec.tls.certificate}')
    
    if [ ! -z "$cert" ]; then
        # Si tiene certificado propio, extraemos la fecha
        expiry=$(echo "$cert" | openssl x509 -enddate -noout | cut -d= -f2)
        echo -e "$ns\t$name\t$expiry\t$host"
    else
        # Si NO tiene certificado propio, es que usa el Wildcard del Router
        # Intentamos ver si es una ruta interna (.apps.kairos...)
        echo -e "$ns\t$name\t[Router Default]\t$host"
    fi
done | column -t -s $'\t'

echo -e "\n--- AUDITORÍA DE SECRETS (Automatización Ansible) ---"
echo -e "NAMESPACE\tSECRET_NAME\tEXPIRATION\tCOMMON_NAME"
echo -e "---------\t-----------\t----------\t-----------"

# 2. Auditoría de SECRETS (Tipo TLS) - Esto te mostrará lo que Ansible ha subido
oc get secrets -A --field-selector type=kubernetes.io/tls -o jsonpath='{range .items[*]}{.metadata.namespace}{","}{.metadata.name}{"\n"}{end}' | while IFS="," read -r ns name; do
    
    cert_data=$(oc get secret "$name" -n "$ns" -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null)
    
    if [ ! -z "$cert_data" ]; then
        expiry=$(echo "$cert_data" | openssl x509 -enddate -noout | cut -d'=' -f2)
        subject=$(echo "$cert_data" | openssl x509 -subject -noout | sed 's/.*CN = //;s/\/.*//')
        echo -e "$ns\t$name\t$expiry\t$subject"
    fi
done | column -t -s $'\t'

