# Manual de Uso para el Script de Generación de Certificados SSL

Este manual describe el uso de los scripts de Bash `generar_cert.sh` y `generar_pfx.sh` para automatizar la creación de certificados SSL utilizando la herramienta `openssl` y el servicio de firma de HARICA.

## Requisitos

* Un sistema operativo basado en Linux.
* La herramienta `openssl` instalada.
* El archivo `template.cnf` debe estar ubicado en el mismo directorio que los scripts.
* Se recomienda tener instalada la herramienta `xclip` para copiar automáticamente el contenido al portapapeles. Si no la tienes, el script seguirá funcionando, pero deberás copiar el contenido del `.csr` manualmente.

## Uso del Script

El proceso de automatización se divide en dos fases.

### Fase 1: Generar la Solicitud de Certificado (`.csr`) y la Clave Privada (`.key`)

En esta fase, el script crea los archivos `.cnf`, `.csr` y `.key` necesarios para solicitar el certificado.

#### 1. Crear la estructura de archivos

Asegúrate de tener el archivo `template.cnf` y los scripts `generar_cert.sh` y `generar_pfx.sh` en el directorio base `/home/jestebanl/certificadosSSL/`.

#### 2. Ejecutar el script

Ejecuta el script `generar_cert.sh` desde la terminal, pasando el nombre de dominio como argumento con la opción `-d`.

./generar_cert.sh -d <nombre_de_dominio>

**Ejemplo:**
./generar_cert.sh -d test.santpau.es

#### 3. Qué hace el script

Al ejecutar el comando, el script realizará las siguientes acciones:

* **Creará una carpeta de trabajo** para el dominio (ej. `test_santpau_es`).
* Dentro de esa carpeta, **creará un subdirectorio** con el año actual (ej. `2025`).
* **Generará el archivo `.cnf`** específico para tu dominio.
* **Creará la clave privada** (`.key`) y la solicitud de firma de certificado (`.csr`) para el dominio.
* **Mostrará el contenido del `.csr`** en la terminal y lo copiará automáticamente al portapapeles.

Una vez que el script finalice, ve a la página de HARICA, pega el contenido del `.csr` y descarga los certificados.

### Fase 2: Renombrar Certificados y Generar el Archivo `.pfx`

En esta fase, el script se encarga de organizar los archivos descargados y de generar el certificado `.pfx` que es necesario para la instalación del certificado.

#### 1. Descargar los certificados

Descarga los **cinco certificados** que te proporciona HARICA y guárdalos en el subdirectorio del año que creó el script (ej. `/home/jestebanl/certificadosSSL/test_santpau_es/2025/`).

Los certificados que debes descargar son:

* `.pem`
* `_bundle.pem`
* `_chain.p7b`
* `_binary.cer`
* `_Issuer.cer`

#### 2. Ejecutar el script

Una vez que los cinco archivos estén en el directorio correcto, ejecuta el segundo script, `generar_pfx.sh`, con el mismo nombre de dominio.

./generar_pfx.sh -d <nombre_de_dominio>

**Ejemplo:**
./generar_pfx.sh -d test.santpau.es

#### 3. Qué hace el script

Este script realiza lo siguiente:

* **Renombra los cinco certificados** descargados con un formato estándar (`test_santpau_es.pem`, etc.).
* **Genera una contraseña aleatoria** para el `.pfx` y la guarda en un archivo llamado `passpfx.txt` dentro del mismo directorio.
* **Genera el archivo `.pfx`** utilizando la clave privada, el certificado `.pem` y la contraseña aleatoria.

Al finalizar, tendrás el archivo `.pfx` y su contraseña listos para usar en la instalación de tu certificado.

## Solución de Problemas

* **Permisos de ejecución:** Si obtienes un error de "permiso denegado", asegúrate de que los scripts sean ejecutables con `chmod +x generar_cert.sh` y `chmod +x generar_pfx.sh`.
* **Archivo `template.cnf` no encontrado:** Asegúrate de que el archivo se encuentre en el mismo directorio que los scripts.
* **`openssl` no encontrado:** Si `openssl` no está en tu sistema, instálalo con el gestor de paquetes de tu distribución (ej. `sudo apt-get install openssl`).
