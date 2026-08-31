#!/bin/bash

#!/bin/bash
# Secure Boot Auditor - Julián Lamadrid (2026)
# Propósito: Validar cumplimiento Secure Boot, Hito 2026 y Trend Micro.

echo "--- Iniciando Auditoría de Seguridad de Arranque ---"

# 1. Verificar si el sistema es EFI
if [ -d /sys/firmware/efi ]; then
    echo "[OK] Firmware: Modo EFI detectado."
else
    echo "[ERROR] Firmware: Modo Legacy/BIOS. Secure Boot es IMPOSIBLE."
    exit 1
fi

# 2. Estado de Secure Boot
SB_STATE=$(mokutil --sb-state 2>/dev/null)
if [[ "$SB_STATE" == *"enabled"* ]]; then
    echo "[OK] Secure Boot: Activo."
else
    echo "[!] Secure Boot: Desactivado en vSphere."
fi

# 3. Preparación Horizonte Junio 2026
echo "--- Verificando Paquetes para Horizonte 2026 ---"
SHIM_VER=$(rpm -q shim --qf "%{VERSION}")
GRUB_VER=$(rpm -q grub2-x86_64-efi --qf "%{VERSION}")

if [[ $(printf '%s\n' "15.8" "$SHIM_VER" | sort -V | head -n1) == "15.8" ]]; then
    echo "[OK] Shim: Versión $SHIM_VER (Seguro para 2026)."
else
    echo "[CRÍTICO] Shim: Versión $SHIM_VER (Vulnerable, requiere update a 15.8)."
fi

# 4. Validación Trend Micro (MOK)
echo "--- Verificando Agente de Seguridad ---"
if lsmod | grep -q "dsa_filter"; then
    echo "[OK] Trend Micro: Módulos cargados correctamente."
else
    echo "[ERROR] Trend Micro: Módulos bloqueados por el Kernel."
    echo "    -> Verificar si la llave 2022 está enrolada:"
    mokutil --list-enrolled | grep -i "Trend Micro" || echo "    [!] Llave de Trend Micro NO detectada en el MOK."
fi

# 5. Modo Lockdown del Kernel
if dmesg | grep -i "Kernel is locked down" > /dev/null; then
    echo "[INFO] Kernel: Modo Lockdown activo (Integridad Verificada)."
fi

echo "--- Auditoría Finalizada ---"


#echo "--- Estado de Secure Boot ---"
#mokutil --sb-state
#echo "--- Módulos de Deep Security ---"
#lsmod | grep ds
#echo "--- Versión exacta del Kernel ---"
#uname -r
#[ -d /sys/firmware/efi ] && echo "EFI Mode" || echo "Legacy BIOS"
#
#fdisk -l /dev/sda | grep -i "disklabel"
#
#rpm -q shim grub2-x86_64-efi
