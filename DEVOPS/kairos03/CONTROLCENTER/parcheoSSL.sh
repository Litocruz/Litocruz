# Definimos las variables con los nuevos archivos
CERT_CC="controlcenter_apps_kairos03_santpau_es_2026.pem"
CA_CC="controlcenter_apps_kairos03_santpau_es_2026_bundle.pem"
KEY_CC="controlcenter_apps_kairos03_santpau_es.key"

# Aplicamos el parche a la Route 'controlcenter'
oc patch route controlcenter -n kafka --type=merge -p "
{
  \"spec\": {
    \"tls\": {
      \"certificate\": \"$(cat $CERT_CC | sed ':a;N;$!ba;s/\n/\\n/g')\",
      \"key\": \"$(cat $KEY_CC | sed ':a;N;$!ba;s/\n/\\n/g')\",
      \"caCertificate\": \"$(cat $CA_CC | sed ':a;N;$!ba;s/\n/\\n/g')\"
    }
  }
}
"
