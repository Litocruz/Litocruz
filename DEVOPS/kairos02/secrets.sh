#!/bin/bash
for ns in bahia-project etc etc-test kafka minio-operator minio-tenant-1 monitorizacion sesiones-clinicas; do
  echo "=== NAMESPACE: $ns (SECRETS TLS) ==="
  for secret in $(oc get secrets -n $ns --field-selector type=kubernetes.io/tls -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    echo -n "Secret: $secret -> "
    oc get secret $secret -n $ns -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null | openssl x509 -enddate -noout 2>/dev/null || echo "No se pudo extraer la fecha"
  done
done
