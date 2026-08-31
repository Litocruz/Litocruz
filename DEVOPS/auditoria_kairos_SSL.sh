#!/bin/bash

# --- AUDITORÍA DE ROUTES ---
echo -e "NAMESPACE\tROUTE\tEXPIRATION\tHOST"
echo -e "---------\t-----\t----------\t----"

# Obtenemos la lista de rutas con TLS en formato 'namespace,name,host'
oc get routes -A -o jsonpath='{range .items[?(@.spec.tls.certificate)]}{.metadata.namespace}{","}{.metadata.name}{","}{.spec.host}{"\n"}{end}' | while IFS="," read -r ns name host; do
    
    # Extraemos el certificado de esa ruta específica
    cert=$(oc get route "$name" -n "$ns" -o jsonpath='{.spec.tls.certificate}')
    
    if [ ! -z "$cert" ]; then
        # Obtenemos la fecha de vencimiento
        expiry=$(echo "$cert" | openssl x509 -enddate -noout | cut -d= -f2)
        echo -e "$ns\t$name\t$expiry\t$host"
    fi
done | column -t -s $'\t'

echo -e "\n"
echo "--------------------------------------------------------------------------------"
echo "--- AUDITORÍA DE SECRETS (TIPO TLS) ---"
echo "--------------------------------------------------------------------------------"
echo -e "NAMESPACE\tSECRET\tEXPIRATION\tSUBJECT/CN"
echo -e "---------\t------\t----------\t----------"

# Buscamos todos los secrets de tipo kubernetes.io/tls
oc get secrets -A --field-selector type=kubernetes.io/tls -o jsonpath='{range .items[*]}{.metadata.namespace}{","}{.metadata.name}{"\n"}{end}' | while IFS="," read -r ns name; do
    
    cert_data=$(oc get secret "$name" -n "$ns" -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null)
    
    if [ ! -z "$cert_data" ]; then
        expiry=$(echo "$cert_data" | openssl x509 -enddate -noout | cut -d'=' -f2)
        # Extraemos el Subject para saber de quién es el certificado
        subject=$(echo "$cert_data" | openssl x509 -subject -noout)
        echo -e "$ns\t$name\t$expiry\t$subject"
    fi
done | column -t -s $'\t'
