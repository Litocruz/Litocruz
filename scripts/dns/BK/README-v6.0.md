Markdown

# Gestor de Registros DNS para BIND (gestionar_dns.sh)

Este script de `bash` es una herramienta de línea de comandos para simplificar la gestión de registros DNS (A y PTR) en un entorno BIND que se administra manualmente. Permite añadir, modificar y renombrar registros de forma semi-automatizada, incorporando múltiples barreras de seguridad para prevenir errores en los ficheros de zona.

---

## ✨ Características Principales

* **Menú interactivo** para elegir la operación a realizar.
* **Añadir Registros**: Crea nuevos registros A (directo) y PTR (inverso). Es capaz de **reparar inconsistencias**, permitiendo reasignar una IP si esta ya tiene un registro PTR incorrecto.
* **Modificar IP**: Cambia la dirección IP de un nombre de host existente, actualizando ambos registros (A y PTR) y manejando ficheros de zona inversa diferentes si es necesario.
* **Renombrar Host**: Cambia el FQDN de un host existente manteniendo su IP, actualizando ambos registros.
* **Multi-Dominio**: Descubre automáticamente el fichero de zona directa correcto (`db.santpau.es`, `db.santpau.cat`, etc.) basándose en el FQDN proporcionado.
* **Inserción Ordenada**: Añade los nuevos registros de forma ordenada en los ficheros de zona para mantener la legibilidad, insertándolos después de la IP o el host secuencialmente anterior.
* **Seguridad Integrada**:
    * Realiza **backups** automáticos antes de cualquier modificación.
    * Valida la sintaxis de los ficheros con `named-checkzone` **antes** de aplicar los cambios.
    * **Restaura automáticamente** los backups si la validación de sintaxis falla, evitando dejar el servicio DNS inoperativo.
    * Utiliza `reload` en lugar de `restart` para aplicar los cambios sin interrumpir el servicio.
* **Auditoría**: Genera un fichero de log (`dns_changes.log`) con cada operación exitosa, registrando qué se hizo, cuándo y por quién.

---

## ⚙️ Requisitos

1.  **Acceso SSH**: Necesitas acceso SSH sin contraseña (mediante clave pública) al servidor DNS Master. El usuario SSH debe tener permisos para:
    * Leer y escribir en el directorio de zonas de BIND (`/var/lib/named/master/`).
    * Ejecutar `systemctl reload named`.
    * Conectarse por SSH al servidor Esclavo para recargarlo.
2.  **Herramientas en el Servidor**: El servidor DNS debe tener instalados los paquetes de BIND (`bind-utils` o `dnsutils`) que proveen `named-checkzone`.
3.  **Herramientas en el Cliente**: Tu máquina local necesita tener `ssh` y `dig` instalados.

---

## 🚀 Instalación

1.  Guarda el código de la última versión en un fichero llamado `gestionar_dns.sh` en tu máquina local.

2.  Abre el fichero y **modifica la sección de `CONFIGURACIÓN`** con los datos de tu entorno. Es fundamental que ajustes estas variables:
    ```bash
    DNS_MASTER="dns01.santpau.es"
    DNS_SLAVE="dns02.santpau.es"
    DNS_USER="root"
    ```

3.  Dale permisos de ejecución al script:
    ```bash
    chmod +x gestionar_dns.sh
    ```

---

## 📖 Modo de Uso

1.  Ejecuta el script en tu terminal:
    ```bash
    ./gestionar_dns.sh
    ```

2.  Aparecerá el menú principal. Elige la opción deseada (1, 2, o 3).

3.  Sigue las instrucciones que te pida el script. Dependiendo de la opción, te solicitará:
    * **Opción 1 (Añadir):** El FQDN completo y la IP del nuevo registro.
    * **Opción 2 (Modificar):** El FQDN del registro a cambiar y la **nueva** IP.
    * **Opción 3 (Renombrar):** El FQDN **antiguo** y el FQDN **nuevo**.

4.  El script realizará comprobaciones previas para evitar conflictos.

5.  Confirma la operación (`s/n`) cuando el script te lo pida. El script se conectará al servidor y realizará todos los pasos de forma automática, informándote del progreso.

---

## 📝 Fichero de Log

Cada vez que una operación se completa con éxito, el script añade una línea al fichero `dns_changes.log` en el mismo directorio. Este log sirve para llevar un registro de auditoría de todos los cambios realizados.

**Ejemplo de línea de log:**
2025-10-08 13:03:11 - ADD/REASSIGN_PTR - FQDN: det-rad-hab101.santpau.es, IP: 172.31.118.108 - Usuario: jestebanl


---

## ⚠️ Advertencia de Seguridad

* Este script modifica ficheros de configuración críticos directamente. Aunque tiene muchas salvaguardas, el riesgo de error nunca es cero. Úsalo con conocimiento.
* El uso del usuario `root` para SSH está configurado por defecto para simplicidad, pero **no es una práctica recomendada**. Se aconseja encarecidamente crear un usuario dedicado con permisos limitados (vía `sudo`) para gestionar los ficheros de BIND y recargar el servicio.
* A largo plazo, se recomienda planificar una migración al método de actualizaciones dinámicas con `nsupdate` y claves TSIG para eliminar la necesidad de editar ficheros directamente y mejorar la seguridad.
