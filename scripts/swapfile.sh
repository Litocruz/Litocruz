#!/bin/bash

# 1. Crea un archivo secuencial de 4GB asignado directamente en la raíz
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096

# 2. Restringe los permisos por seguridad (solo el root puede leer/escribir)
sudo chmod 600 /swapfile

# 3. Inicializa el archivo como espacio de intercambio de Linux
sudo mkswap /swapfile

# 4. Activa la SWAP inmediatamente en caliente
sudo swapon /swapfile
