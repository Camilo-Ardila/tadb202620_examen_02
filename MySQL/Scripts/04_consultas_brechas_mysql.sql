-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 04: consultas (Etapas 3 y 4) con elementos de mejora al desempeño
-- Motor   : MySQL 8.4 (contenedor Docker tadb_ex02_mysql, puerto 3307)
-- Autores : Camilo José Ardila Restrepo - ID 000543367
--           David Berrío Martínez       - ID 000547257
-- Archivo : UTF-8, texto plano
--
-- Requisito: haber ejecutado los scripts 01 (modelo), 02 (carga) y
-- 03 (funciones, procedimientos y vistas).
--
-- Metodología de la comparación de desempeño
--   Los índices de desempeño se crean en el script 01 (modelo):
--     Etapa 3: idx_tipo_dato_categoria, idx_butd_tipo_dato
--     Etapa 4: idx_butd_usuario_org_fecha
--   Para obtener la LÍNEA BASE sin eliminarlos (cada uno sostiene una
--   FK), se marcan como INVISIBLE: el optimizador los ignora pero siguen
--   existiendo. Luego se marcan VISIBLE y se vuelve a obtener el plan.
--
--   Para cada consulta se registra:
--     - EXPLAIN FORMAT=TREE : árbol de operaciones, filas y costo estimado
--     - EXPLAIN ANALYZE     : el mismo árbol con filas y tiempos reales
--   En DBeaver también puede verse el plan gráfico: seleccionar la
--   consulta y usar Ctrl+Shift+E (Explicar plan de ejecución).
--
-- Ejecución: conectado como root. Cada bloque puede ejecutarse por
-- separado con Ctrl+Enter (cursor dentro de la sentencia) o todo el
-- script con Alt+X.
-- =====================================================================

USE brechas_seguridad;


-- =====================================================================
-- ETAPA 3
-- Brechas críticas del último año con mayor impacto en usuarios
--
-- Para el último año, todas las brechas de severidad alta o crítica que
-- hayan expuesto al menos un dato de categoría de sensibilidad crítica.
-- Muestra: organización, código de brecha, fecha de detección, vector de
-- ataque y número total de usuarios distintos afectados por la brecha,
-- ordenado de mayor a menor número de usuarios afectados.
--
-- Decisiones:
--   - "Último año" = brechas detectadas en los últimos 12 meses respecto
--     a la fecha de ejecución: [CURDATE() - 1 año, CURDATE()].
--   - "Alta o crítica" = nivel_severidad_incidente >= 3.
--   - "Sensibilidad crítica" = nivel_categoria_sensibilidad = 4.
--   - El dato crítico es una condición de existencia (EXISTS); el conteo
--     incluye a TODOS los usuarios distintos de la brecha, no solo a los
--     que tuvieron un dato crítico expuesto.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Línea base: índices de desempeño invisibles para el optimizador
-- ---------------------------------------------------------------------
ALTER TABLE tipo_dato_expuesto       ALTER INDEX idx_tipo_dato_categoria INVISIBLE;

ALTER TABLE brecha_usuario_tipo_dato ALTER INDEX idx_butd_tipo_dato INVISIBLE;

ANALYZE TABLE tipo_dato_expuesto, brecha_usuario_tipo_dato;

EXPLAIN FORMAT=TREE
SELECT o.nombre_organizacion,
       b.codigo_brecha,
       b.fecha_deteccion_brecha,
       v.nombre_vector_ataque,
       COUNT(DISTINCT x.id_usuario) AS usuarios_afectados
  FROM brecha_seguridad b
  JOIN severidad_incidente s      ON s.id_severidad_incidente = b.id_severidad_incidente
  JOIN organizacion o             ON o.id_organizacion = b.id_organizacion
  JOIN vector_ataque v            ON v.id_vector_ataque = b.id_vector_ataque
  JOIN brecha_usuario_tipo_dato x ON x.id_brecha_seguridad = b.id_brecha_seguridad
 WHERE b.fecha_deteccion_brecha BETWEEN CURDATE() - INTERVAL 1 YEAR AND CURDATE()
   AND s.nivel_severidad_incidente >= 3
   AND EXISTS (SELECT 1
                 FROM brecha_usuario_tipo_dato xc
                 JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = xc.id_tipo_dato_expuesto
                 JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                WHERE xc.id_brecha_seguridad = b.id_brecha_seguridad
                  AND c.nivel_categoria_sensibilidad = 4)
 GROUP BY b.id_brecha_seguridad, o.nombre_organizacion, b.codigo_brecha,
          b.fecha_deteccion_brecha, v.nombre_vector_ataque
 ORDER BY usuarios_afectados DESC, b.codigo_brecha;

EXPLAIN ANALYZE
SELECT o.nombre_organizacion,
       b.codigo_brecha,
       b.fecha_deteccion_brecha,
       v.nombre_vector_ataque,
       COUNT(DISTINCT x.id_usuario) AS usuarios_afectados
  FROM brecha_seguridad b
  JOIN severidad_incidente s      ON s.id_severidad_incidente = b.id_severidad_incidente
  JOIN organizacion o             ON o.id_organizacion = b.id_organizacion
  JOIN vector_ataque v            ON v.id_vector_ataque = b.id_vector_ataque
  JOIN brecha_usuario_tipo_dato x ON x.id_brecha_seguridad = b.id_brecha_seguridad
 WHERE b.fecha_deteccion_brecha BETWEEN CURDATE() - INTERVAL 1 YEAR AND CURDATE()
   AND s.nivel_severidad_incidente >= 3
   AND EXISTS (SELECT 1
                 FROM brecha_usuario_tipo_dato xc
                 JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = xc.id_tipo_dato_expuesto
                 JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                WHERE xc.id_brecha_seguridad = b.id_brecha_seguridad
                  AND c.nivel_categoria_sensibilidad = 4)
 GROUP BY b.id_brecha_seguridad, o.nombre_organizacion, b.codigo_brecha,
          b.fecha_deteccion_brecha, v.nombre_vector_ataque
 ORDER BY usuarios_afectados DESC, b.codigo_brecha;

-- Resultado esperado de la línea base: para verificar si cada brecha
-- expuso un dato crítico, el motor recorre la tabla de tipos de dato
-- ("Table scan on t") y lee TODAS las exposiciones de la brecha en la PK
-- de la tabla puente (~50 filas por brecha).

-- ---------------------------------------------------------------------
-- 3.2 Mejora:
--   - idx_tipo_dato_categoria: obtiene directamente los tipos de dato de
--     categoría crítica (sin recorrer el catálogo).
--   - idx_butd_tipo_dato: por ser secundario, InnoDB le agrega la PK, así
--     que equivale a (tipo, brecha, usuario). Con él, la condición EXISTS
--     se resuelve con una búsqueda puntual (tipo crítico, brecha) en un
--     índice de cobertura, en lugar de leer todas las exposiciones.
--   - El conteo de usuarios distintos aprovecha que la PK de la tabla
--     puente (índice agrupado) está ordenada por id_brecha_seguridad.
-- ---------------------------------------------------------------------
ALTER TABLE tipo_dato_expuesto       ALTER INDEX idx_tipo_dato_categoria VISIBLE;

ALTER TABLE brecha_usuario_tipo_dato ALTER INDEX idx_butd_tipo_dato VISIBLE;

ANALYZE TABLE tipo_dato_expuesto, brecha_usuario_tipo_dato;

EXPLAIN FORMAT=TREE
SELECT o.nombre_organizacion,
       b.codigo_brecha,
       b.fecha_deteccion_brecha,
       v.nombre_vector_ataque,
       COUNT(DISTINCT x.id_usuario) AS usuarios_afectados
  FROM brecha_seguridad b
  JOIN severidad_incidente s      ON s.id_severidad_incidente = b.id_severidad_incidente
  JOIN organizacion o             ON o.id_organizacion = b.id_organizacion
  JOIN vector_ataque v            ON v.id_vector_ataque = b.id_vector_ataque
  JOIN brecha_usuario_tipo_dato x ON x.id_brecha_seguridad = b.id_brecha_seguridad
 WHERE b.fecha_deteccion_brecha BETWEEN CURDATE() - INTERVAL 1 YEAR AND CURDATE()
   AND s.nivel_severidad_incidente >= 3
   AND EXISTS (SELECT 1
                 FROM brecha_usuario_tipo_dato xc
                 JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = xc.id_tipo_dato_expuesto
                 JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                WHERE xc.id_brecha_seguridad = b.id_brecha_seguridad
                  AND c.nivel_categoria_sensibilidad = 4)
 GROUP BY b.id_brecha_seguridad, o.nombre_organizacion, b.codigo_brecha,
          b.fecha_deteccion_brecha, v.nombre_vector_ataque
 ORDER BY usuarios_afectados DESC, b.codigo_brecha;

EXPLAIN ANALYZE
SELECT o.nombre_organizacion,
       b.codigo_brecha,
       b.fecha_deteccion_brecha,
       v.nombre_vector_ataque,
       COUNT(DISTINCT x.id_usuario) AS usuarios_afectados
  FROM brecha_seguridad b
  JOIN severidad_incidente s      ON s.id_severidad_incidente = b.id_severidad_incidente
  JOIN organizacion o             ON o.id_organizacion = b.id_organizacion
  JOIN vector_ataque v            ON v.id_vector_ataque = b.id_vector_ataque
  JOIN brecha_usuario_tipo_dato x ON x.id_brecha_seguridad = b.id_brecha_seguridad
 WHERE b.fecha_deteccion_brecha BETWEEN CURDATE() - INTERVAL 1 YEAR AND CURDATE()
   AND s.nivel_severidad_incidente >= 3
   AND EXISTS (SELECT 1
                 FROM brecha_usuario_tipo_dato xc
                 JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = xc.id_tipo_dato_expuesto
                 JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                WHERE xc.id_brecha_seguridad = b.id_brecha_seguridad
                  AND c.nivel_categoria_sensibilidad = 4)
 GROUP BY b.id_brecha_seguridad, o.nombre_organizacion, b.codigo_brecha,
          b.fecha_deteccion_brecha, v.nombre_vector_ataque
 ORDER BY usuarios_afectados DESC, b.codigo_brecha;

-- ---------------------------------------------------------------------
-- 3.3 Ejecución de la consulta (registros resultantes)
-- ---------------------------------------------------------------------
SELECT o.nombre_organizacion,
       b.codigo_brecha,
       b.fecha_deteccion_brecha,
       v.nombre_vector_ataque,
       COUNT(DISTINCT x.id_usuario) AS usuarios_afectados
  FROM brecha_seguridad b
  JOIN severidad_incidente s      ON s.id_severidad_incidente = b.id_severidad_incidente
  JOIN organizacion o             ON o.id_organizacion = b.id_organizacion
  JOIN vector_ataque v            ON v.id_vector_ataque = b.id_vector_ataque
  JOIN brecha_usuario_tipo_dato x ON x.id_brecha_seguridad = b.id_brecha_seguridad
 WHERE b.fecha_deteccion_brecha BETWEEN CURDATE() - INTERVAL 1 YEAR AND CURDATE()
   AND s.nivel_severidad_incidente >= 3
   AND EXISTS (SELECT 1
                 FROM brecha_usuario_tipo_dato xc
                 JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = xc.id_tipo_dato_expuesto
                 JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                WHERE xc.id_brecha_seguridad = b.id_brecha_seguridad
                  AND c.nivel_categoria_sensibilidad = 4)
 GROUP BY b.id_brecha_seguridad, o.nombre_organizacion, b.codigo_brecha,
          b.fecha_deteccion_brecha, v.nombre_vector_ataque
 ORDER BY usuarios_afectados DESC, b.codigo_brecha;


-- La misma consulta encapsulada en un procedimiento (script 03).
-- NULL = último año contado desde la fecha actual.
CALL sp_brechas_criticas_ultimo_anio(NULL);


-- =====================================================================
-- ETAPA 4
-- Historial de exposición de un usuario específico
--
-- Solicitud de derecho de acceso: dado el código del usuario, en qué
-- brechas se vio afectado, qué tipo de dato se expuso en cada una, la
-- categoría de sensibilidad del dato, la organización responsable y la
-- fecha de notificación, ordenado cronológicamente por notificación.
--
-- Usuario de ejemplo: US-002823 (afectado por 14 brechas, 16 exposiciones).
-- Para consultar otro usuario, cambie el valor de @codigo_usuario.
-- =====================================================================
SET @codigo_usuario = 'US-002823';

-- ---------------------------------------------------------------------
-- 4.1 Línea base: índice de cobertura invisible para el optimizador
-- ---------------------------------------------------------------------
ALTER TABLE brecha_usuario_tipo_dato ALTER INDEX idx_butd_usuario_org_fecha INVISIBLE;

ANALYZE TABLE brecha_usuario_tipo_dato;

EXPLAIN FORMAT=TREE
SELECT b.codigo_brecha,
       t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad,
       o.nombre_organizacion,
       x.fecha_notificacion_usuario
  FROM usuario u
  JOIN brecha_usuario_tipo_dato x ON x.id_usuario = u.id_usuario
  JOIN brecha_seguridad b         ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o             ON o.id_organizacion = x.id_organizacion
  JOIN tipo_dato_expuesto t       ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c   ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
 WHERE u.codigo_usuario = @codigo_usuario
 ORDER BY x.fecha_notificacion_usuario, b.codigo_brecha, t.nombre_tipo_dato_expuesto;

EXPLAIN ANALYZE
SELECT b.codigo_brecha,
       t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad,
       o.nombre_organizacion,
       x.fecha_notificacion_usuario
  FROM usuario u
  JOIN brecha_usuario_tipo_dato x ON x.id_usuario = u.id_usuario
  JOIN brecha_seguridad b         ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o             ON o.id_organizacion = x.id_organizacion
  JOIN tipo_dato_expuesto t       ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c   ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
 WHERE u.codigo_usuario = @codigo_usuario
 ORDER BY x.fecha_notificacion_usuario, b.codigo_brecha, t.nombre_tipo_dato_expuesto;

-- Resultado esperado de la línea base: sin un índice que empiece por
-- id_usuario, el motor recorre las brechas y busca al usuario dentro de
-- la PK de la tabla puente brecha por brecha (cientos de búsquedas).
-- Nota: el índice sigue sosteniendo la FK compuesta aunque esté
-- invisible; solo el optimizador deja de usarlo para las consultas.

-- ---------------------------------------------------------------------
-- 4.2 Mejora: índice de cobertura (id_usuario, id_organizacion,
--     fecha_notificacion_usuario), que además soporta la FK compuesta
--     (usuario, organización). Ubica directamente las filas del usuario
--     (su organización es una sola, así que quedan ordenadas por fecha),
--     y como InnoDB guarda la PK en cada entrada del índice secundario,
--     obtiene brecha y tipo de dato sin leer la tabla puente.
-- ---------------------------------------------------------------------
ALTER TABLE brecha_usuario_tipo_dato ALTER INDEX idx_butd_usuario_org_fecha VISIBLE;

ANALYZE TABLE brecha_usuario_tipo_dato;

EXPLAIN FORMAT=TREE
SELECT b.codigo_brecha,
       t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad,
       o.nombre_organizacion,
       x.fecha_notificacion_usuario
  FROM usuario u
  JOIN brecha_usuario_tipo_dato x ON x.id_usuario = u.id_usuario
  JOIN brecha_seguridad b         ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o             ON o.id_organizacion = x.id_organizacion
  JOIN tipo_dato_expuesto t       ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c   ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
 WHERE u.codigo_usuario = @codigo_usuario
 ORDER BY x.fecha_notificacion_usuario, b.codigo_brecha, t.nombre_tipo_dato_expuesto;

EXPLAIN ANALYZE
SELECT b.codigo_brecha,
       t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad,
       o.nombre_organizacion,
       x.fecha_notificacion_usuario
  FROM usuario u
  JOIN brecha_usuario_tipo_dato x ON x.id_usuario = u.id_usuario
  JOIN brecha_seguridad b         ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o             ON o.id_organizacion = x.id_organizacion
  JOIN tipo_dato_expuesto t       ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c   ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
 WHERE u.codigo_usuario = @codigo_usuario
 ORDER BY x.fecha_notificacion_usuario, b.codigo_brecha, t.nombre_tipo_dato_expuesto;

-- ---------------------------------------------------------------------
-- 4.3 Ejecución de la consulta (registros resultantes)
--     Se usa el código literal (no la variable @codigo_usuario) porque
--     la exportación de resultados de DBeaver vuelve a ejecutar la
--     consulta en una conexión nueva, donde la variable no existe.
-- ---------------------------------------------------------------------
SELECT b.codigo_brecha,
       t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad,
       o.nombre_organizacion,
       x.fecha_notificacion_usuario
  FROM usuario u
  JOIN brecha_usuario_tipo_dato x ON x.id_usuario = u.id_usuario
  JOIN brecha_seguridad b         ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o             ON o.id_organizacion = x.id_organizacion
  JOIN tipo_dato_expuesto t       ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c   ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
 WHERE u.codigo_usuario = 'US-002823'
 ORDER BY x.fecha_notificacion_usuario, b.codigo_brecha, t.nombre_tipo_dato_expuesto;

-- La misma consulta encapsulada en un procedimiento (script 03),
-- para atender solicitudes de derecho de acceso con el usuario brechas_app.
CALL sp_historial_exposicion_usuario('US-002823');

-- Fin del script 04
