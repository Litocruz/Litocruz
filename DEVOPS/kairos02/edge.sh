#!/bin/bash
for ns in bahia-project etc etc-test kafka minio-operator minio-tenant-1 monitorizacion sesiones-clinicas; do
  echo "=== NAMESPACE: $ns (ROUTES) ==="
  oc get routes -n $ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.host}{"\t"}{.spec.tls.termination}{"\n"}{end}' 2>/dev/null | while read name host term; do
    if [ -n "$name" ]; then
      echo -n "Route: $name | Host: $host | TLS: $term -> "
      cert=$(oc get route $name -n $ns -o jsonpath='{.spec.tls.certificate}' 2>/dev/null)
      if [ -n "$cert" ]; then
        echo "$cert" | openssl x509 -enddate -noout 2>/dev/null || echo "Error leyendo cert custom"
      else
        echo "Usa el certificado por defecto del Router de OpenShift"
      fi
    fi
  done
done
