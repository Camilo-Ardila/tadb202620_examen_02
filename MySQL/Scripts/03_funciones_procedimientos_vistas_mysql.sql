-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 03: funciones, procedimientos y vistas
-- Motor   : MySQL 8.4 (contenedor Docker tadb_ex02_mysql, puerto 3307)
-- Autores : Camilo José Ardila Restrepo - ID 000543367
--           David Berrío Martínez       - ID 000547257
-- Archivo : UTF-8, texto plano
--
-- Requisito: haber ejecutado los scripts 01 (modelo) y 02 (carga).
--
-- Contenido:
--   0. Limpieza (permite re-ejecutar el script)
--   1. Funciones
--   2. Procedimientos
--   3. Vistas
--   4. Privilegios mínimos sobre los nuevos objetos
--   5. Pruebas
--
-- Triggers: el modelo no los necesita. La regla "la organización de la
-- brecha y la del usuario deben coincidir" la garantizan las FK
-- compuestas de la tabla puente (script 01), y la regla "la notificación
-- no puede ser anterior a la detección" se verifica en la carga
-- (script 02, validación 4.2), como indica la nota 5 del diagrama.
--
-- Ejecución: conectado como root desde DBeaver. Ejecutar como SCRIPT
-- COMPLETO con Alt+X, sin texto seleccionado.
-- =====================================================================

USE brechas_seguridad;


-- =====================================================================
-- 0. LIMPIEZA
-- =====================================================================
DROP FUNCTION IF EXISTS fn_dias_hasta_deteccion;

DROP FUNCTION IF EXISTS fn_usuarios_afectados_brecha;

DROP FUNCTION IF EXISTS fn_brecha_expuso_dato_critico;

DROP PROCEDURE IF EXISTS sp_brechas_criticas_ultimo_anio;

DROP PROCEDURE IF EXISTS sp_historial_exposicion_usuario;

DROP VIEW IF EXISTS v_exposicion_detalle;

DROP VIEW IF EXISTS v_brecha_detalle;


-- DELIMITER cambia el separador de sentencias a $$ para que los ";"
-- internos de cada función o procedimiento no terminen la sentencia.
DELIMITER $$

-- =====================================================================
-- 1. FUNCIONES
-- Devuelven un único valor y pueden usarse dentro de un SELECT.
-- READS SQL DATA: la función lee tablas pero no las modifica.
-- DETERMINISTIC: con los mismos datos y parámetros, devuelve lo mismo.
-- =====================================================================

-- 1.1 Días entre la ocurrencia y la detección de una brecha.
-- El enunciado resalta este intervalo ("puede ser de meses") como un
-- factor clave del incidente.
CREATE FUNCTION fn_dias_hasta_deteccion(p_id_brecha_seguridad INTEGER)
RETURNS INTEGER
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_dias INTEGER;

    SELECT DATEDIFF(fecha_deteccion_brecha, fecha_ocurrencia_brecha)
      INTO v_dias
      FROM brecha_seguridad
     WHERE id_brecha_seguridad = p_id_brecha_seguridad;

    RETURN v_dias;
END$$

-- 1.2 Número de usuarios distintos afectados por una brecha.
-- Un usuario puede tener varios tipos de dato expuestos en la misma
-- brecha (varias filas en la tabla puente), por eso COUNT(DISTINCT).
CREATE FUNCTION fn_usuarios_afectados_brecha(p_id_brecha_seguridad INTEGER)
RETURNS INTEGER
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total INTEGER;

    SELECT COUNT(DISTINCT id_usuario)
      INTO v_total
      FROM brecha_usuario_tipo_dato
     WHERE id_brecha_seguridad = p_id_brecha_seguridad;

    RETURN v_total;
END$$

-- 1.3 Indica si una brecha expuso al menos un dato de sensibilidad
-- crítica (nivel 4). Devuelve 1 (sí) o 0 (no).
CREATE FUNCTION fn_brecha_expuso_dato_critico(p_id_brecha_seguridad INTEGER)
RETURNS TINYINT
READS SQL DATA
DETERMINISTIC
BEGIN
    RETURN EXISTS (SELECT 1
                     FROM brecha_usuario_tipo_dato x
                     JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
                     JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                    WHERE x.id_brecha_seguridad = p_id_brecha_seguridad
                      AND c.nivel_categoria_sensibilidad = 4);
END$$


-- =====================================================================
-- 2. PROCEDIMIENTOS
-- Encapsulan las consultas de las etapas 3 y 4 para que la aplicación
-- (usuario brechas_app) las ejecute con CALL sin acceso a escribir SQL.
-- =====================================================================

-- 2.1 Etapa 3: brechas de severidad alta o crítica, detectadas en el
-- último año, que expusieron al menos un dato de sensibilidad crítica,
-- con el total de usuarios distintos afectados (de mayor a menor).
--   p_fecha_referencia: fecha desde la que se cuenta el año hacia atrás.
--   Si es NULL se usa la fecha actual (CURDATE()).
CREATE PROCEDURE sp_brechas_criticas_ultimo_anio(IN p_fecha_referencia DATE)
BEGIN
    DECLARE v_fecha_fin    DATE DEFAULT COALESCE(p_fecha_referencia, CURDATE());
    DECLARE v_fecha_inicio DATE DEFAULT COALESCE(p_fecha_referencia, CURDATE()) - INTERVAL 1 YEAR;

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
     WHERE b.fecha_deteccion_brecha BETWEEN v_fecha_inicio AND v_fecha_fin
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
END$$

-- 2.2 Etapa 4: solicitud de derecho de acceso. Dado el código de un
-- usuario, devuelve en qué brechas se vio afectado, qué dato se expuso,
-- su categoría de sensibilidad, la organización responsable y la fecha
-- de notificación, en orden cronológico de notificación.
-- Si el código no existe, devuelve un mensaje en lugar de un resultado
-- vacío.
CREATE PROCEDURE sp_historial_exposicion_usuario(IN p_codigo_usuario VARCHAR(10))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE codigo_usuario = p_codigo_usuario) THEN
        SELECT CONCAT('No existe un usuario con código ', IFNULL(p_codigo_usuario, '(vacío)')) AS mensaje;
    ELSE
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
         WHERE u.codigo_usuario = p_codigo_usuario
         ORDER BY x.fecha_notificacion_usuario, b.codigo_brecha, t.nombre_tipo_dato_expuesto;
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- 3. VISTAS
-- Consultas guardadas con nombre. No almacenan datos: cada vez que se
-- consultan, ejecutan su SELECT sobre las tablas. Sirven para leer el
-- modelo normalizado "como sábana" sin escribir todos los JOIN.
-- =====================================================================

-- 3.1 Cada exposición (fila de la tabla puente) con sus descriptores
CREATE VIEW v_exposicion_detalle AS
SELECT u.codigo_usuario,
       u.pseudonimo_usuario,
       b.codigo_brecha,
       o.nombre_organizacion,
       t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad,
       c.nivel_categoria_sensibilidad,
       b.fecha_deteccion_brecha,
       x.fecha_notificacion_usuario
  FROM brecha_usuario_tipo_dato x
  JOIN usuario u                ON u.id_usuario = x.id_usuario
  JOIN brecha_seguridad b       ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o           ON o.id_organizacion = x.id_organizacion
  JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad;

-- 3.2 Cada brecha con sus catálogos resueltos y los días hasta detección
CREATE VIEW v_brecha_detalle AS
SELECT b.id_brecha_seguridad,
       b.codigo_brecha,
       o.nombre_organizacion,
       se.nombre_sector_economico,
       p.nombre_pais AS pais_organizacion,
       v.nombre_vector_ataque,
       sv.nombre_severidad_incidente,
       sv.nivel_severidad_incidente,
       b.fecha_ocurrencia_brecha,
       b.fecha_deteccion_brecha,
       DATEDIFF(b.fecha_deteccion_brecha, b.fecha_ocurrencia_brecha) AS dias_hasta_deteccion,
       b.registros_afectados_total_brecha,
       b.costo_estimado_total_brecha
  FROM brecha_seguridad b
  JOIN organizacion o         ON o.id_organizacion = b.id_organizacion
  JOIN sector_economico se    ON se.id_sector_economico = o.id_sector_economico
  JOIN pais p                 ON p.id_pais = o.id_pais_organizacion
  JOIN vector_ataque v        ON v.id_vector_ataque = b.id_vector_ataque
  JOIN severidad_incidente sv ON sv.id_severidad_incidente = b.id_severidad_incidente;


-- =====================================================================
-- 4. PRIVILEGIOS MÍNIMOS SOBRE LOS NUEVOS OBJETOS
-- brechas_app puede leer las vistas y ejecutar funciones y procedimientos,
-- pero no crearlos, modificarlos ni escribir en las tablas.
-- (brechas_owner ya tiene CREATE VIEW, CREATE ROUTINE y EXECUTE sobre
-- todo el esquema desde el script 01.)
-- =====================================================================
GRANT SELECT ON brechas_seguridad.v_exposicion_detalle TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.v_brecha_detalle TO 'brechas_app'@'%';

GRANT EXECUTE ON FUNCTION brechas_seguridad.fn_dias_hasta_deteccion TO 'brechas_app'@'%';

GRANT EXECUTE ON FUNCTION brechas_seguridad.fn_usuarios_afectados_brecha TO 'brechas_app'@'%';

GRANT EXECUTE ON FUNCTION brechas_seguridad.fn_brecha_expuso_dato_critico TO 'brechas_app'@'%';

GRANT EXECUTE ON PROCEDURE brechas_seguridad.sp_brechas_criticas_ultimo_anio TO 'brechas_app'@'%';

GRANT EXECUTE ON PROCEDURE brechas_seguridad.sp_historial_exposicion_usuario TO 'brechas_app'@'%';


-- =====================================================================
-- 5. PRUEBAS
-- =====================================================================

-- 5.1 Funciones sobre la brecha BR-00001
SELECT codigo_brecha,
       fn_dias_hasta_deteccion(id_brecha_seguridad)       AS dias_hasta_deteccion,
       fn_usuarios_afectados_brecha(id_brecha_seguridad)  AS usuarios_afectados,
       fn_brecha_expuso_dato_critico(id_brecha_seguridad) AS expuso_dato_critico
  FROM brecha_seguridad
 WHERE codigo_brecha = 'BR-00001';

-- 5.2 Vistas
SELECT * FROM v_brecha_detalle ORDER BY dias_hasta_deteccion DESC LIMIT 10;

SELECT * FROM v_exposicion_detalle WHERE codigo_usuario = 'US-002823';

-- 5.3 Procedimiento de la etapa 3 (último año desde hoy)
CALL sp_brechas_criticas_ultimo_anio(NULL);

-- 5.4 Procedimiento de la etapa 4 (usuario de ejemplo y código inexistente)
CALL sp_historial_exposicion_usuario('US-002823');

CALL sp_historial_exposicion_usuario('US-999999');

-- 5.5 Objetos creados en el esquema
SELECT routine_type, routine_name
  FROM information_schema.routines
 WHERE routine_schema = 'brechas_seguridad'
 ORDER BY routine_type, routine_name;

SHOW GRANTS FOR 'brechas_app'@'%';

-- Fin del script 03
