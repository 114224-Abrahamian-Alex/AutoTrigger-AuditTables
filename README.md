Un script de SQL que hice para crear las tablas de Audit y los triggers para generar las copias. 

¿Como funciona? 
Simple, una vez crean toda la base, ejecutan este script y les genera todas las tablas que existan en la base con el prefijo de "_audit".

Si quieren excluir alguna tabla ahí deje un comentario para excluir las tablas que ya tengan el "_audit", deberian agregar al where la tabla que no quieran hacerle su tabla audit
