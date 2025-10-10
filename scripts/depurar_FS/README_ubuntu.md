Consideraciones de Seguridad y Notas:
rm -rf: El comando rm -rf es muy potente. Siempre que el script lo usa (en /tmp y ~/.cache), está precedido por una confirmación explícita. ¡Úsalo con extrema precaución!

Permisos de sudo: Algunas operaciones requieren sudo (permisos de superusuario).

Archivos de usuario: El script limpia ~/.cache. No toca tus documentos, fotos, etc., pero si tienes datos importantes en la caché (aunque no debería ser así), haz una copia de seguridad.

Exclusiones: En el informe de archivos grandes, se excluyen directorios como /proc, /sys y /dev porque son sistemas de archivos virtuales y no contienen archivos que puedas eliminar para liberar espacio. También excluye /snap ya que los paquetes snap son auto-contenidos y su gestión requiere comandos específicos.

Kernels antiguos: No se incluyó una limpieza automática de kernels antiguos para mantener la seguridad y evitar pasos complejos, ya que un error podría dejar el sistema inestable.

Snaps/Flatpaks: Para liberar espacio de paquetes Snap o Flatpak, se necesitan comandos específicos (ej. sudo snap remove --purge <paquete> o flatpak uninstall --unused). No se incluyeron para mantener la simplicidad y el enfoque en el sistema de archivos tradicional.
