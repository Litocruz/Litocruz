Usaremos una estrategia de "cascada" para determinar el estado, probando varios métodos:

Método 1: ¿Es un sistema EFI?

Verificaremos si existe el directorio /sys/firmware/efi.

Si no existe, la VM está arrancando en modo BIOS (Legacy). Secure Boot no es aplicable. Lo marcaremos como bios_boot.

Método 2: (Si es EFI) Probar mokutil

Si el directorio EFI existe, intentaremos ejecutar mokutil --sb-state.

Si funciona, usaremos su salida (enabled o disabled).

Método 3: (Si es EFI y mokutil falla) Probar dmesg

Si mokutil no se encuentra o falla, buscaremos en el buffer de mensajes del kernel (dmesg) pistas sobre Secure Boot.

Buscaremos "Secure boot enabled" o "Secure boot disabled". Esto es menos fiable (el buffer puede haber rotado), pero es el mejor segundo intento sin instalar nada.

Estado Final: unknown_efi

Si es EFI, pero mokutil falló y dmesg no nos dio información, lo marcaremos como unknown_efi. Esto te indica las VMs que son EFI pero que no pudiste auditar.
