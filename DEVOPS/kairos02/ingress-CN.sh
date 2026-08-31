#!/bin/bash
for ns in bahia-project etc etc-test kafka minio-operator minio-tenant-1 monitorizacion sesiones-clinicas; do
  echo "=== NAMESPACE: $ns (INGRESSES) ==="
  oc get ingress -n $ns -o jsonpath='{range .items[*]}Ingress: {.metadata.name} | Hosts Destino: {.spec.rules[*].host} | Secreto Asociado: {.spec.tls[*].secretName}{"\n"}{end}' 2>/dev/null
done

