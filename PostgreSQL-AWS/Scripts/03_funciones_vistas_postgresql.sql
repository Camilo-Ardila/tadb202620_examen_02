-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 03: funciones y vistas (PostgreSQL 18.3 / Amazon RDS)
-- Adaptado desde el script original en MySQL 8.4.
--
-- Se ejecuta conectado como "brechas_camilo" a la base
-- "brechas_seguridad". Requiere haber corrido los scripts 00, 01 y 02.
--
-- Cambios de fondo respecto al original en MySQL:
--   - Los dos "PROCEDURE" de MySQL se convierten en FUNCTIONS que
--     devuelven TABLE(...), porque CREATE PROCEDURE de PostgreSQL no
--     puede devolver un result set vía CALL. Se invocan con
--     SELECT * FROM nombre(parametros), no con CALL.
--   - sp_historial_exposicion_usuario: cuando el usuario no existe, en
--     vez de devolver una fila de texto, lanza RAISE NOTICE y devuelve
--     0 filas (una función tiene una sola forma de salida fija).
--   - DATEDIFF(a, b) -> en PostgreSQL, "fecha_a - fecha_b" entre dos
--     DATE ya devuelve un INTEGER (días), sin función aparte.
--   - TINYINT (0/1) -> BOOLEAN nativo de PostgreSQL.
--   - DETERMINISTIC / READS SQL DATA (MySQL) -> STABLE (PostgreSQL):
--     la función lee tablas pero no escribe, y da el mismo resultado
--     para los mismos argumentos dentro de una misma sentencia.
--   - DELIMITER $$ no existe en PostgreSQL: el cuerpo de cada función
--     va entre $$ ... $$ directamente, sin cambiar el separador global.
--   - Todo el bloque de creación corre con SET ROLE brechas_owner_role,
--     igual que las tablas en el script 01, para que los objetos
--     queden con ese rol como dueño y tanto camilo como david tengan
--     control total sin necesitar GRANTs adicionales entre ellos.
--   - Se omite la sección de privilegios a 'brechas_app' del original:
--     ese rol de solo lectura no existe en este modelo (camilo y david
--     ya tienen control total vía brechas_owner_role). Si más adelante
--     agregan un rol de solo consulta, al final del archivo dejo la
--     plantilla comentada.
-- =====================================================================


-- =====================================================================
-- 0. LIMPIEZA (permite re-ejecutar el script)
-- =====================================================================
DROP FUNCTION IF EXISTS fn_dias_hasta_deteccion(INTEGER);
DROP FUNCTION IF EXISTS fn_usuarios_afectados_brecha(INTEGER);
DROP FUNCTION IF EXISTS fn_brecha_expuso_dato_critico(INTEGER);
DROP FUNCTION IF EXISTS sp_brechas_criticas_ultimo_anio(DATE);
DROP FUNCTION IF EXISTS sp_historial_exposicion_usuario(VARCHAR);
DROP VIEW IF EXISTS v_exposicion_detalle;
DROP VIEW IF EXISTS v_brecha_detalle;


-- Las funciones y vistas quedan con brechas_owner_role como dueño
-- (igual que las tablas en el script 01).
SET ROLE brechas_owner_role;


-- =====================================================================
-- 1. FUNCIONES
-- =====================================================================

-- 1.1 Días entre la ocurrencia y la detección de una brecha.
CREATE FUNCTION fn_dias_hasta_deteccion(p_id_brecha_seguridad INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_dias INTEGER;
BEGIN
    SELECT fecha_deteccion_brecha - fecha_ocurrencia_brecha
      INTO v_dias
      FROM brecha_seguridad
     WHERE id_brecha_seguridad = p_id_brecha_seguridad;

    RETURN v_dias;
END;
$$;

-- 1.2 Número de usuarios distintos afectados por una brecha.
CREATE FUNCTION fn_usuarios_afectados_brecha(p_id_brecha_seguridad INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total INTEGER;
BEGIN
    SELECT COUNT(DISTINCT id_usuario)
      INTO v_total
      FROM brecha_usuario_tipo_dato
     WHERE id_brecha_seguridad = p_id_brecha_seguridad;

    RETURN v_total;
END;
$$;

-- 1.3 Indica si una brecha expuso al menos un dato de sensibilidad
-- crítica (nivel 4). BOOLEAN nativo en vez de TINYINT 1/0.
CREATE FUNCTION fn_brecha_expuso_dato_critico(p_id_brecha_seguridad INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN EXISTS (SELECT 1
                     FROM brecha_usuario_tipo_dato x
                     JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
                     JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
                    WHERE x.id_brecha_seguridad = p_id_brecha_seguridad
                      AND c.nivel_categoria_sensibilidad = 4);
END;
$$;


-- =====================================================================
-- 2. "PROCEDIMIENTOS" (funciones que devuelven TABLE; ver nota arriba)
-- Se invocan con SELECT * FROM nombre(parametros), no con CALL.
-- =====================================================================

-- 2.1 Etapa 3: brechas de severidad alta o crítica, detectadas en el
-- último año, que expusieron al menos un dato de sensibilidad crítica.
-- p_fecha_referencia NULL -> se usa CURRENT_DATE.
CREATE FUNCTION sp_brechas_criticas_ultimo_anio(p_fecha_referencia DATE DEFAULT NULL)
RETURNS TABLE (
    nombre_organizacion    VARCHAR(100),
    codigo_brecha          VARCHAR(10),
    fecha_deteccion_brecha DATE,
    nombre_vector_ataque   VARCHAR(50),
    usuarios_afectados     BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_fecha_fin    DATE := COALESCE(p_fecha_referencia, CURRENT_DATE);
    v_fecha_inicio DATE := (COALESCE(p_fecha_referencia, CURRENT_DATE) - INTERVAL '1 year')::DATE;
BEGIN
    RETURN QUERY
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
END;
$$;

-- 2.2 Etapa 4: historial de exposición de un usuario por código.
-- Si el código no existe: RAISE NOTICE + 0 filas (ver nota arriba).
CREATE FUNCTION sp_historial_exposicion_usuario(p_codigo_usuario VARCHAR(10))
RETURNS TABLE (
    codigo_brecha                 VARCHAR(10),
    nombre_tipo_dato_expuesto     VARCHAR(50),
    nombre_categoria_sensibilidad VARCHAR(20),
    nombre_organizacion           VARCHAR(100),
    fecha_notificacion_usuario    DATE
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE codigo_usuario = p_codigo_usuario) THEN
        RAISE NOTICE 'No existe un usuario con código %', COALESCE(p_codigo_usuario, '(vacío)');
        RETURN;
    END IF;

    RETURN QUERY
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
END;
$$;


-- =====================================================================
-- 3. VISTAS
-- =====================================================================

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
       (b.fecha_deteccion_brecha - b.fecha_ocurrencia_brecha) AS dias_hasta_deteccion,
       b.registros_afectados_total_brecha,
       b.costo_estimado_total_brecha
  FROM brecha_seguridad b
  JOIN organizacion o         ON o.id_organizacion = b.id_organizacion
  JOIN sector_economico se    ON se.id_sector_economico = o.id_sector_economico
  JOIN pais p                 ON p.id_pais = o.id_pais_organizacion
  JOIN vector_ataque v        ON v.id_vector_ataque = b.id_vector_ataque
  JOIN severidad_incidente sv ON sv.id_severidad_incidente = b.id_severidad_incidente;


RESET ROLE;


-- =====================================================================
-- 4. PRIVILEGIOS -- plantilla por si agregan un rol de solo lectura
-- más adelante (hoy no existe ese rol en este modelo, así que no hay
-- nada que ejecutar aquí):
--
-- GRANT SELECT ON v_exposicion_detalle, v_brecha_detalle TO <rol_lectura>;
-- GRANT EXECUTE ON FUNCTION fn_dias_hasta_deteccion(INTEGER) TO <rol_lectura>;
-- GRANT EXECUTE ON FUNCTION fn_usuarios_afectados_brecha(INTEGER) TO <rol_lectura>;
-- GRANT EXECUTE ON FUNCTION fn_brecha_expuso_dato_critico(INTEGER) TO <rol_lectura>;
-- GRANT EXECUTE ON FUNCTION sp_brechas_criticas_ultimo_anio(DATE) TO <rol_lectura>;
-- GRANT EXECUTE ON FUNCTION sp_historial_exposicion_usuario(VARCHAR) TO <rol_lectura>;
-- =====================================================================


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

-- 5.3 "Procedimiento" de la etapa 3 (último año desde hoy)
-- Antes: CALL sp_brechas_criticas_ultimo_anio(NULL);
SELECT * FROM sp_brechas_criticas_ultimo_anio(NULL);

-- 5.4 "Procedimiento" de la etapa 4 (usuario de ejemplo y código inexistente)
-- Antes: CALL sp_historial_exposicion_usuario('US-002823');
SELECT * FROM sp_historial_exposicion_usuario('US-002823');

SELECT * FROM sp_historial_exposicion_usuario('US-999999');

-- 5.5 Objetos creados en el esquema
SELECT routine_type, routine_name
  FROM information_schema.routines
 WHERE routine_schema = 'public'
 ORDER BY routine_type, routine_name;

-- Dueño de cada función (debe ser brechas_owner_role)
SELECT p.proname AS nombre_funcion, pg_get_userbyid(p.proowner) AS dueno
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
 ORDER BY p.proname;

-- Dueño de cada vista (debe ser brechas_owner_role)
SELECT viewname, viewowner
  FROM pg_views
 WHERE schemaname = 'public'
 ORDER BY viewname;

-- Fin del script 03
