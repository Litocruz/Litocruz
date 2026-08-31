# Definimos la fecha de corte: archivos modificados ANTES del 1 de enero de 2026
FECHA_CORTE="2025-01-01"
ARCHIVO_TAR="backup_antiguos_logs_$(date +%Y%m%d).tar.gz"

echo "Buscando y comprimiendo archivos en / modificados antes de $FECHA_CORTE..."
echo "Nota: Se omitirán otros filesystems (-xdev)."

# 1. Buscamos los archivos y los pasamos a tar
# Usamos -xdev para no salir de /
# Usamos -type f para no intentar comprimir directorios (que rompería la estructura)
sudo find /opt/liferay-ce-portal-7.3.5-ga6/logs -xdev -type f ! -newermt "$FECHA_CORTE" -print0 | \
	    sudo tar -cvzf "$ARCHIVO_TAR" --null -T - --remove-files

echo "Proceso finalizado. El backup se encuentra en: $ARCHIVO_TAR"

