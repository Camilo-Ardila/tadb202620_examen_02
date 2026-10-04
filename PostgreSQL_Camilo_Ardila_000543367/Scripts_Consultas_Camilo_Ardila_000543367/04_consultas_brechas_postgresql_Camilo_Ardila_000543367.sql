-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 04: consultas (Etapas 3 y 4) con elementos de mejora al
-- desempeño (PostgreSQL 18.3 / Amazon RDS)
-- Adaptado desde el script original en MySQL 8.4.
--
-- Integrantes:
--           Camilo José Ardila Restrepo - ID 000543367
--           David Berrío Martínez       - ID 000547257
--
-- Se ejecuta conectado como "brechas_camilo" a la base
-- "brechas_seguridad". Requiere haber corrido los scripts 00, 01, 02 y
-- 03.
--
-- CAMBIO IMPORTANTE respecto a versiones anteriores de este archivo:
-- las consultas que se van a usar para capturar el plan de ejecución
-- YA NO llevan "EXPLAIN" ni "EXPLAIN ANALYZE" escritos a mano. Se
-- generan desde el panel gráfico de DBeaver (Ctrl+Shift+E -> marcar
-- ANALYSE y BUFFERS en "Extra EXPLAIN settings" -> OK), que agrega su
-- propio EXPLAIN por detrás. Si a una consulta que ya tiene "EXPLAIN"
-- escrito se le aplica además el de DBeaver, quedan dos EXPLAIN
-- seguidos y el servidor lo rechaza con "syntax error at or near
-- EXPLAIN" -- ese fue el error que salió al correr una versión previa
-- de este script con el panel.
--
-- Por el mismo motivo, cada consulta aparece UNA sola vez por etapa
-- (no una copia para EXPLAIN y otra para EXPLAIN ANALYZE): con
-- ANALYSE+BUFFERS marcados en el panel de DBeaver, una sola corrida de
-- Ctrl+Shift+E ya muestra costo, filas estimadas, filas reales y
-- buffers juntos -- no hace falta una segunda consulta de texto plano.
--
-- Metodología de la comparación de desempeño
--   PostgreSQL NO tiene índices invisibles (confirmado en la
--   documentación de AWS; ni siquiera Aurora los soporta). La
--   comunidad de PostgreSQL recomienda lo que se hace aquí: DROP INDEX
--   para medir la línea base, y volver a crearlo para medir la mejora.
--
-- Otros cambios de sintaxis respecto al original en MySQL:
--   - ANALYZE TABLE t1, t2 -> ANALYZE t1, t2 (sin la palabra TABLE).
--   - CURDATE() -> CURRENT_DATE; "CURDATE() - INTERVAL 1 YEAR" ->
--     "(CURRENT_DATE - INTERVAL '1 year')::DATE".
--   - SET @codigo_usuario = '...' (variable de MySQL) -> en este
--     archivo se usa el literal 'US-002823' directo en cada consulta,
--     porque DBeaver (a diferencia de psql) no soporta variables de
--     sesión ni sustitución de variables de cliente. Para consultar
--     otro usuario, cambien el literal en las 2 consultas de la
--     Etapa 4.
--   - CALL sp_xxx(...) -> SELECT * FROM sp_xxx(...), porque en el
--     script 03 esos "procedimientos" son funciones que devuelven
--     TABLE.
--   - InnoDB agrega la PK a cada entrada de un índice secundario
--     (índice agrupado); un índice B-tree de PostgreSQL NO hace eso,
--     así que el acceso a columnas no indexadas casi siempre implica
--     un Heap Fetch adicional (a menos que se use INCLUDE).
-- =====================================================================


-- =====================================================================
-- ETAPA 3
-- Brechas críticas del último año con mayor impacto en usuarios
-- (alta/crítica = nivel >= 3, sensibilidad crítica = nivel 4, el
-- EXISTS no restringe el conteo de usuarios a los que tuvieron el dato
-- crítico expuesto).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Línea base: sin los índices de desempeño (se borran, no se
-- "ocultan" -- PostgreSQL no tiene índices invisibles).
-- ---------------------------------------------------------------------
DROP INDEX IF EXISTS idx_tipo_dato_categoria;
DROP INDEX IF EXISTS idx_butd_tipo_dato;

ANALYZE tipo_dato_expuesto, brecha_usuario_tipo_dato;

-- CAPTURA 1 (línea base): cursor en esta consulta -> Ctrl+Shift+E ->
-- marcar ANALYSE + BUFFERS -> OK
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
 WHERE b.fecha_deteccion_brecha BETWEEN (CURRENT_DATE - INTERVAL '1 year')::DATE AND CURRENT_DATE
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

-- Resultado esperado de la línea base: Seq Scan sobre tipo_dato_expuesto
-- para resolver qué tipos son de categoría crítica, y para el EXISTS,
-- un plan poco selectivo sobre brecha_usuario_tipo_dato.

-- ---------------------------------------------------------------------
-- 3.2 Mejora: se recrean los índices (definición idéntica al script 01)
-- ---------------------------------------------------------------------
SET ROLE brechas_owner_role;

CREATE INDEX idx_tipo_dato_categoria ON tipo_dato_expuesto (id_categoria_sensibilidad);
CREATE INDEX idx_butd_tipo_dato      ON brecha_usuario_tipo_dato (id_tipo_dato_expuesto);

RESET ROLE;

ANALYZE tipo_dato_expuesto, brecha_usuario_tipo_dato;

-- CAPTURA 2 (mejora): misma consulta, mismo Ctrl+Shift+E
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
 WHERE b.fecha_deteccion_brecha BETWEEN (CURRENT_DATE - INTERVAL '1 year')::DATE AND CURRENT_DATE
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

-- Resultado esperado de la mejora: idx_tipo_dato_categoria da un Index
-- Scan directo sobre los tipos de categoría crítica. idx_butd_tipo_dato
-- permite resolver el EXISTS con Index Scan/Bitmap Index Scan en vez de
-- Seq Scan completo. OJO: a diferencia de InnoDB, este índice solo
-- tiene id_tipo_dato_expuesto -- para confirmar id_brecha_seguridad
-- probablemente sigue haciendo falta un Heap Fetch.

-- ---------------------------------------------------------------------
-- 3.3 Ejecución de la consulta (registros resultantes) -- CAPTURA 3
-- Ctrl+Enter normal (sin Explain) para ver la grilla de resultados.
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
 WHERE b.fecha_deteccion_brecha BETWEEN (CURRENT_DATE - INTERVAL '1 year')::DATE AND CURRENT_DATE
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

-- La misma consulta encapsulada en la función del script 03.
-- Antes: CALL sp_brechas_criticas_ultimo_anio(NULL);
SELECT * FROM sp_brechas_criticas_ultimo_anio(NULL);


-- =====================================================================
-- ETAPA 4
-- Historial de exposición de un usuario específico.
-- Usuario de ejemplo: US-002823 (literal directo -- ver nota de
-- cambios de sintaxis al inicio del archivo sobre por qué no se usa
-- variable de sesión aquí).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 Línea base: sin el índice de cobertura
-- ---------------------------------------------------------------------
DROP INDEX IF EXISTS idx_butd_usuario_org_fecha;

ANALYZE brecha_usuario_tipo_dato;

-- CAPTURA 4 (línea base): Ctrl+Shift+E -> ANALYSE + BUFFERS
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

-- Resultado esperado de la línea base: sin un índice que arranque por
-- id_usuario, el planificador probablemente hace un Seq Scan sobre
-- brecha_usuario_tipo_dato (la PK compuesta arranca por
-- id_brecha_seguridad, no sirve para filtrar directo por usuario).

-- ---------------------------------------------------------------------
-- 4.2 Mejora: se recrea el índice de cobertura (definición idéntica al
-- script 01, incluida la nota de PG18 sobre skip scan).
-- ---------------------------------------------------------------------
SET ROLE brechas_owner_role;

CREATE INDEX idx_butd_usuario_org_fecha
    ON brecha_usuario_tipo_dato (id_usuario, id_organizacion, fecha_notificacion_usuario);

RESET ROLE;

ANALYZE brecha_usuario_tipo_dato;

-- CAPTURA 5 (mejora): misma consulta, mismo Ctrl+Shift+E
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

-- Resultado esperado de la mejora: idx_butd_usuario_org_fecha permite
-- un Index Scan directo por id_usuario, con las filas ya ordenadas por
-- fecha_notificacion_usuario. OJO: a diferencia de InnoDB, este índice
-- no lleva automáticamente id_brecha_seguridad ni id_tipo_dato_expuesto
-- en sus hojas, así que probablemente sigue habiendo un Heap Fetch por
-- fila. Un índice de cobertura total se lograría con INCLUDE, p.ej.:
--   CREATE INDEX ... ON brecha_usuario_tipo_dato
--     (id_usuario, id_organizacion, fecha_notificacion_usuario)
--     INCLUDE (id_brecha_seguridad, id_tipo_dato_expuesto);

-- ---------------------------------------------------------------------
-- 4.3 Ejecución de la consulta (registros resultantes) -- CAPTURA 6
-- Ctrl+Enter normal (sin Explain).
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

-- La misma consulta encapsulada en la función del script 03.
-- Antes: CALL sp_historial_exposicion_usuario('US-002823');
SELECT * FROM sp_historial_exposicion_usuario('US-002823');

-- Fin del script 04
