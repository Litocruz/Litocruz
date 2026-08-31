***HOSPITAL DE LA SANTA CREU I SANT PAU***
*Infraestructuras / Sistemas Linux*
***Procedimiento Operativo: Renovación de Certificado SSL (HARICA) en HAProxy***
*Versión 1.0*
*Fecha: 30 de abril de 2026*

**Información del documento**
| **Nombre del documento** | Procedimiento Operativo: Renovación de Certificado SSL (HARICA) en HAProxy |
| :--- | :--- |
| **Fecha de creación** | 30/04/2026 |
| **Fecha de impresión** | [PENDIENTE: COMPLETAR POR SISTEMAS] |
| **Versión** | 1.0 |

**Control de cambios**
| **Edición** | **Fecha** | **Descripción de los Cambios** |
| :--- | :--- | :--- |
| v1.0 | 30/04/2026 | Creación del documento operativo para la renovación de certificados de Webmail/Exchange en HAProxy. |

**Revisión del documento**
| **Versión** | **Fecha** | **Elaborado** | **Revisado** | **Aprobado** |
| :--- | :--- | :--- | :--- | :--- |
| v1.0 | 30/04/2026 | Administrador de Sistemas Linux | [PENDIENTE: COMPLETAR POR SISTEMAS] | [PENDIENTE: COMPLETAR POR SISTEMAS] |

**Índice**
1. Introducción y objetivos
2. Roles y responsabilidades
3. Diagrama de flujo
4. Descripción del procedimiento

---

### 1 Introducción y objetivos

#### 1.1 Objetivo del documento
El objetivo de este documento es definir el procedimiento operativo detallado para la extracción, preparación, validación y despliegue de la renovación del certificado SSL emitido por HARICA para los servicios alojados detrás de los balanceadores HAProxy.

#### 1.2 Alcance
Este procedimiento aplica exclusivamente a los siguientes elementos de la infraestructura:
*   **Servicio:** Webmail / Exchange (`correuhsp.santpau.cat`).
*   **Servidores Balanceadores:** `exhsp-proxy-pass` y `exhsp-proxy-pass-int`.
*   **Ruta Destino HAProxy:** `/etc/haproxy/correuhsp_santpau_cat_HAProxy.pem`.

#### 1.3 Definiciones y siglas
*   **HAProxy:** Software de balanceo de carga y proxy.
*   **HARICA:** Entidad certificadora que emite los certificados SSL corporativos.
*   **Bundle / PEM:** Archivo unificado que contiene la clave privada y toda la cadena de confianza del certificado SSL.

---

### 2 Roles y responsabilidades

| **Rol** | **Responsabilidad** |
| :--- | :--- |
| **Administrador de Sistemas** | Responsable de acceder a los servidores balanceadores, construir el archivo de certificado ("bundle"), validar la sintaxis en HAProxy y realizar la recarga del servicio garantizando el correcto funcionamiento mediante pruebas. |

---

### 3 Diagrama de flujo

*[PENDIENTE: COMPLETAR POR SISTEMAS - Insertar diagrama visual en Word/Visio del flujo descrito a continuación]*

1.  **Inicio (1):** Descarga de certificados desde HARICA.
2.  **Actividad (2):** Descompresión en el servidor `exhsp-proxy-pass`.
3.  **Actividad (3):** Backup del certificado actual.
4.  **Actividad (4):** Construcción del "Bundle" (.pem) y purga de metadatos.
5.  **Decisión (5):** ¿Validación de sintaxis de HAProxy correcta? (Sí -> Continuar / No -> Revisar Bundle).
6.  **Actividad (6):** Recarga suave del servicio (`reload`).
7.  **Fin (7):** Comprobación externa de conectividad y fechas.

---

### 4 Descripción del procedimiento

A continuación, se describen los pasos secuenciales para llevar a cabo la intervención basándose en el flujo de trabajo.

#### Fase 1: Preparación y Extracción
Una vez descargado el archivo `.zip` con los certificados desde el portal de HARICA al servidor balanceador (`exhsp-proxy-pass`), se debe proceder a su descompresión.

1.  Navegar al directorio de trabajo temporal donde se subió el `.zip`:
    ```bash
    cd /home/logicalis/certs/
    ```
2.  Descomprimir el archivo descargado:
    ```bash
    unzip correuhsp_santpau_cat_2026.zip
    ```

**Nota importante sobre los archivos extraídos:** De todos los ficheros resultantes, **solo utilizaremos dos** para HAProxy:
*   `correuhsp_santpau_cat/2026/correuhsp_santpau_cat_2026_bundle_root.pem`: Contiene el certificado del servidor, el certificado intermedio y el certificado Root.
*   `correuhsp_santpau_cat/correuhsp_santpau_cat.key`: Contiene la llave privada correspondiente.

#### Fase 2: Construcción del "Bundle" para HAProxy
HAProxy requiere que toda la cadena de certificados y la llave privada residan en un único archivo. **Es estrictamente necesario** que este archivo no contenga metadatos de texto fuera de las etiquetas `-----BEGIN...` y `-----END...`.

1.  Realizar un backup preventivo del certificado actualmente en producción:
    ```bash
    cp /etc/haproxy/correuhsp_santpau_cat_HAProxy.pem /etc/haproxy/oldfiles/correuhsp_santpau_cat_HAProxy.pem-$(date +%F)
    ```
2.  Unir el certificado completo y la llave privada aplicando un filtro mediante `awk` para eliminar cualquier texto informativo o "basura" que pueda ocasionar un `SSL handshake failure` en HAProxy:
    ```bash
    cat correuhsp_santpau_cat/2026/correuhsp_santpau_cat_2026_bundle_root.pem correuhsp_santpau_cat/correuhsp_santpau_cat.key | awk '/BEGIN/{f=1} f; /END/{f=0}' > /etc/haproxy/correuhsp_santpau_cat_HAProxy.pem
    ```
3.  Ajustar los permisos para proteger el archivo, permitiendo la lectura únicamente a `root` (y al proceso de HAProxy):
    ```bash
    chmod 600 /etc/haproxy/correuhsp_santpau_cat_HAProxy.pem
    ```

#### Fase 3: Validación y Despliegue
**Precaución:** Nunca se debe reiniciar HAProxy sin antes validar que el nuevo archivo tiene un formato correcto.

1.  Verificar la sintaxis de la configuración del balanceador:
    ```bash
    haproxy -c -f /etc/haproxy/haproxy.cfg
    ```
    *ℹ️ Resultado esperado: El comando debe devolver `Configuration file is valid`. (Se pueden ignorar posibles alertas de tipo `[WARNING]` relacionadas con modos HTTP).*
2.  Aplicar los cambios recargando el servicio de forma suave, para no cortar las conexiones activas:
    ```bash
    systemctl reload haproxy
    ```

#### Fase 4: Comprobación Final
Para garantizar que HAProxy ha cargado correctamente el archivo en memoria y lo está sirviendo hacia Internet, simular una conexión de cliente mediante el siguiente comando:

```bash
echo | openssl s_client -connect 84.88.183.25:443 -servername correuhsp.santpau.cat 2>/dev/null | openssl x509 -noout -dates
ℹ️ Resultado esperado: Las fechas notBefore y notAfter arrojadas por la salida deben reflejar el nuevo periodo de validez. Si las fechas son correctas, el despliegue ha sido exitoso.

