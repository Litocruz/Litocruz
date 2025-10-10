## Cómo Usar el Script
Guarda el código: Abre un editor de texto como nano y pega el código. Guarda el archivo con el nombre depurar_root.sh.

Bash

nano depurar_root.sh
Dale permisos de ejecución:

Bash

chmod +x depurar_root.sh
Ejecútalo con sudo:

Bash

sudo ./depurar_root.sh
## Cómo Interpretar el Informe y Actuar
Top 10 Directorios: El informe te dirá qué carpetas (/var, /usr, etc.) ocupan más espacio. Esto te da una pista de dónde empezar a buscar. Si /var/log es muy grande, hay que revisar los logs. Si es /var/cache, se puede limpiar.

Snapshots de Snapper: Esta es la causa más común en SUSE. Si ves un número muy alto de snapshots, esta es tu prioridad. El script te muestra el comando para borrarlos. Borrar snapshots viejos puede liberar gigabytes de espacio al instante.

Acciones Sugeridas: Los comandos para limpiar la caché de zypper y los logs del sistema son seguros y puedes ejecutarlos para una ganancia de espacio rápida.
