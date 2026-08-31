#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA DE PLANTILLAS JINJA2 PARA ANSIBLE
# ==============================================================================
# Ejecuta este script en tu máquina de control de Ansible, idealmente en el 
# mismo directorio donde tienes almacenados tus playbooks (.yml).
# ==============================================================================

set -euo pipefail

# 1. Definir directorio de plantillas (debe llamarse 'templates' junto al playbook)
TEMPLATE_DIR="templates"

echo "=== [1/3] Creando directorio de plantillas: $TEMPLATE_DIR ==="
mkdir -p "$TEMPLATE_DIR"

# 2. Generar plantilla para Reporte de Kernel (CVE-2026-31431)
# Esta plantilla corresponde exactamente al archivo actualmente abierto en el Canvas.
echo "=== [2/3] Generando plantilla: $TEMPLATE_DIR/cve_31431_report.j2 ==="
cat << 'EOF' > "$TEMPLATE_DIR/cve_31431_report.j2"
# REPORTE DE EJECUCIÓN: WORKAROUND CVE-2026-31431
Generado el: {{ ansible_date_time.date }} a las {{ ansible_date_time.time }}

## RESUMEN DE ESTADO POR HOST:
{% for host in groups['linux_vms'] %}
* **{{ host }}**: {{ hostvars[host]['mitigation_summary'] | default('Fallo de Conexion/Ejecucion') }}
{% endfor %}
EOF

# 3. Generar plantilla para Reporte de PackageKit (CVE-2026-41651)
echo "=== [3/3] Generando plantilla: $TEMPLATE_DIR/cve_41651_report.j2 ==="
cat << 'EOF' > "$TEMPLATE_DIR/cve_41651_report.j2"
# REPORTE DE EJECUCIÓN: PURGA DE PACKAGEKIT (CVE-2026-41651)
Generado el: {{ ansible_date_time.date }} a las {{ ansible_date_time.time }}

## RESUMEN DE ESTADO POR HOST:
{% for host in groups['linux_vms'] %}
* **{{ host }}**: {{ hostvars[host]['packagekit_action'] | default('Fallo de Conexion/Ejecucion') }}
{% endfor %}
EOF

echo "=============================================================================="
echo " CONFIGURACIÓN COMPLETADA CON ÉXITO"
echo "=============================================================================="
echo "Se ha creado la carpeta y las plantillas en:"
echo "  - $TEMPLATE_DIR/cve_31431_report.j2"
echo "  - $TEMPLATE_DIR/cve_41651_report.j2"
echo ""
echo "Asegúrate de ejecutar tus playbooks (.yml) desde este mismo directorio para"
echo "que Ansible localice automáticamente la carpeta '$TEMPLATE_DIR' sin rutas absolutas."
echo "=============================================================================="
```
eof
