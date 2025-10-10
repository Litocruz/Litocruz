
Cómo funciona la lógica
Pedirá el nombre de dominio completo (FQDN),  por ejemplo: maquina-nueva.campussantpau.cat.

Búsqueda Inteligente del Fichero: El script analizará ese FQDN y buscará en el directorio /var/lib/named/master/ el fichero de zona que mejor coincida.

Si introduces pc1.santpau.es, buscará y encontrará db.santpau.es.

Si introduces servidor-proyecto.campussantpau.cat, buscará y encontrará db.campussantpau.cat.

Adaptación Automática: Una vez que encuentra el fichero correcto, todo el resto del proceso (backup, cálculo de SOA, edición y validación) se ejecutará sobre ese fichero.

3. Ejecución Remota de Tareas
Esta sección empaqueta un conjunto de instrucciones y las envía al servidor dns01 para que las ejecute de una sola vez.

ssh -T "${DNS_USER}@${DNS_MASTER}" bash -s -- "$FQDN" "$IP" ... << 'EOF'

ssh -T ...: Inicia una conexión SSH con el servidor DNS. La opción -T es para evitar problemas al no necesitar una terminal interactiva.

bash -s -- "$FQDN" "$IP" ...: Le dice al servidor remoto que ejecute un script de bash. Lo que viene a continuación (<< 'EOF') será el contenido de ese script. Los argumentos ($FQDN, $IP, etc.) se pasan de forma segura para que el script remoto pueda usarlos.

<< 'EOF' ... EOF: Esto se conoce como "Here Document". Todo lo que está entre estas dos etiquetas se envía al servidor como si fuera un único fichero de script. La set -e al principio es una medida de seguridad que hace que el script se detenga inmediatamente si cualquier comando falla.

Lógica dentro del Servidor Remoto
Una vez dentro del servidor, el script realiza los siguientes pasos:

1. Búsqueda del Fichero de Zona (find_forward_zone_file)
Esta es la parte más inteligente del script.

Propósito: Averiguar qué fichero de zona directa (ej: db.santpau.es, db.campussantpau.cat) corresponde al FQDN que has introducido (ej: maquina.santpau.es).

Funcionamiento:

Prueba con el dominio completo: Para maquina.santpau.es, busca si existe el fichero db.maquina.santpau.es.

Si no lo encuentra, le quita la primera parte (maquina) y prueba con lo que queda: Busca si existe db.santpau.es.

¡Lo encuentra! Y devuelve db.santpau.es como el fichero correcto a editar.

Si no encontrara ningún fichero coincidente, daría un error.

2. Identificación de Ficheros y Nombres
Con la información anterior, define todas las variables que necesitará:

FORWARD_ZONE_FILE: La ruta completa al fichero de zona directa que encontró (ej: /var/lib/named/master/db.santpau.es).

REVERSE_ZONE_FILE: Construye el nombre del fichero de zona inversa invirtiendo los tres primeros octetos de la IP. Para 172.31.98.105, crea el nombre db.98.31.172.in-addr.arpa.

HOSTNAME y LAST_OCTET: Extrae las partes necesarias para escribir los registros, como el nombre corto de la máquina y el último número de la IP.

3. Backup
cp -p "$FORWARD_ZONE_FILE" "${FORWARD_ZONE_FILE}-..."

Antes de tocar nada, crea una copia de seguridad de los dos ficheros que va a modificar (el directo y el inverso). El nombre del backup incluye la fecha y hora exactas (YYYYMMDD-HHMMSS) para que sea único.

4. Cálculo del Nuevo SOA
calculate_new_soa()

Esta función se encarga de actualizar el número de serie (SOA) correctamente.

Lee el número de serie actual del fichero.

Compara la parte de la fecha (YYYYMMDD) con la fecha de hoy.

Si es el mismo día, incrementa el contador diario (nn) en 1 (ej: de 01 a 02).

Si es un día nuevo, resetea el contador diario a 01 y usa la fecha de hoy.
Esto garantiza que el nuevo número de serie siempre sea mayor que el anterior, algo crucial para que los servidores DNS esclavos se actualicen.

5. Edición de los Ficheros
Aquí es donde se realizan los cambios:

sed -i.bak ...: Usa el comando sed para buscar la línea del número de serie en ambos ficheros y la reemplaza con el nuevo SOA que se calculó en el paso anterior.

Para la Zona Inversa: El script busca el último octeto anterior más próximo. Si vas a añadir el .200, buscará primero la línea del .199. Si no la encuentra, buscará la del .198, y así sucesivamente. Cuando encuentra una, inserta el nuevo registro justo debajo. Si no encuentra ningún número secuencial anterior, lo añade al final como antes.

Para la Zona Directa: Aplica la misma lógica, pero buscando la dirección IP completa anterior más próxima en el fichero.

6. Validación de Sintaxis (¡El Paso de Seguridad Más Importante!) 🛡️
named-checkzone "$DOMAIN" "$FORWARD_ZONE_FILE"

Antes de atreverse a reiniciar el servicio, el script utiliza la herramienta oficial de BIND, named-checkzone, para verificar que la sintaxis de los ficheros modificados es perfecta.

Si hay un error: Si la validación falla, el script muestra un mensaje de ¡ERROR DE SINTAXIS!, automáticamente restaura los ficheros originales desde el backup que creó y se detiene en seco. Esto evita dejar el DNS roto.

7. Reinicio de Servicios
systemctl restart named

Solo si la validación fue exitosa, el script procede a reiniciar el servicio named en el servidor maestro (dns01) para que aplique los cambios. Después, intenta hacer lo mismo en el servidor esclavo (dns02) a través de otro ssh.

8. Limpieza
mv "${FORWARD_ZONE_FILE}-${BACKUP_SUFFIX}" "${ZONE_PATH}/old/"

Si todo el proceso ha sido un éxito, el script mueve los ficheros de backup a la carpeta old/ para mantener el directorio principal limpio y archivar los cambios.

9. Logs
Al final del script (en tu máquina local), se ha añadido una sección que comprueba si la ejecución remota fue exitosa.

Si todo salió bien, creará o añadirá una línea a un fichero dns_changes.log en la misma carpeta donde ejecutes el script.

Cada línea del log tendrá este formato: Fecha Hora - ADD - FQDN: maquina.santpau.es, IP: 172.31.55.200 - Usuario: tu_usuario_local.

Análisis de Seguridad del Script

1. Operación Reversible: Backups Automáticos
Qué hace: Justo antes de tocar cualquier fichero, el script crea una copia exacta con una marca de tiempo (cp -p ...).

Nivel de seguridad: Alto. Garantiza que siempre tienes una versión funcional a la que volver si algo sale catastróficamente mal.

2. Barrera de Contención: Validación de Sintaxis (El más importante) 🛡️
Qué hace: Después de editar los ficheros, pero antes de reiniciar el servicio, el script usa el comando oficial de BIND, named-checkzone. Este comando simula cómo BIND leería el fichero y comprueba si la sintaxis es 100% correcta.

Nivel de seguridad: Crítico. Esta es la red de seguridad más importante. Asegura que el servicio named no fallará al arrancar por culpa de un error de sintaxis introducido por el script (un punto y coma faltante, un tabulador mal puesto, etc.).

3. Recuperación Automática: Restauración en Caso de Error
Qué hace: Si la validación de named-checkzone falla, el script no continúa. Inmediatamente, muestra un mensaje de error y usa los backups para restaurar los ficheros a su estado original.

Nivel de seguridad: Crítico. Esta es la acción que se deriva de la barrera anterior. No solo te avisa del error, sino que deshace la operación fallida por ti, dejando el sistema estable.

4. Ejecución a Prueba de Fallos: set -e
Qué hace: El bloque de comandos que se ejecuta en el servidor remoto comienza con set -e. Esto le dice a bash que aborte el script inmediatamente si cualquier comando falla (por ejemplo, si no puede crear un backup por un problema de permisos).

Nivel de seguridad: Alto. Previene que el script continúe ejecutándose en un estado inconsistente o inesperado.

5. Prevención de Errores: Comprobaciones Previas y Confirmación
Qué hace: El script comprueba desde el principio si los registros ya existen para evitar duplicados y te pide una confirmación manual (s/n) antes de realizar cualquier cambio.

Nivel de seguridad: Medio. No es una protección técnica contra la corrupción, pero es una excelente protección contra errores de operación por parte del usuario.

6. Mejora: Uso de reload en lugar de restart
He realizado un último ajuste: he cambiado systemctl restart named por systemctl reload named.

reload es más seguro y profesional: No detiene el servicio en ningún momento. Simplemente le indica a BIND que vuelva a cargar las zonas desde los ficheros, lo que causa cero tiempo de inactividad para las consultas DNS.
