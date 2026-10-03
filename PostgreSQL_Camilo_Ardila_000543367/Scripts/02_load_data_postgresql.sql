-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
--
-- Script 02: carga de datos (PostgreSQL 18.3 / Amazon RDS)
--
-- Integrantes:
--           Camilo José Ardila Restrepo - ID 000543367
--           David Berrío Martínez       - ID 000547257
--
-- Se ejecuta conectado como "brechas_camilo" (NO como postgres), a la
-- base "brechas_seguridad". Usa el meta-comando \copy de psql (no el
-- COPY de servidor) porque lee los CSV desde el cliente, lo cual
-- funciona sin ser superusuario.
--
-- Rutas relativas: asumen que psql se ejecuta desde la carpeta
--   ...\tadb202620_examen_02\PostgreSQL-AWS\Scripts
-- y los CSV están en
--   ...\tadb202620_examen_02\data\sabana_brechas_seguridad_lote_N.csv
--
-- IMPORTANTE - supuesto a confirmar: severidad_incidente y
-- categoria_sensibilidad_dato llegan en el CSV solo como texto (p.ej.
-- "Alta"), pero las tablas catálogo exigen también un nivel numérico
-- 1-4. Se asume la escala Baja=1, Media=2, Alta=3, Crítica=4. Si tus
-- CSV usan otras etiquetas, el script se detiene con un error
-- explícito listando los valores no reconocidos (ver DO blocks más
-- abajo) -- ajusta el CASE correspondiente y vuelve a correr.
-- =====================================================================

-- Si cualquier sentencia falla, detener el script en vez de seguir
-- ejecutando el resto con una transacción ya abortada.
\set ON_ERROR_STOP on

BEGIN;

-- =====================================================================
-- 1. TABLA TEMPORAL (sábana cruda, todo TEXT para no perder filas por
--    errores de formato durante la carga -- el cast/validación de tipos
--    ocurre más adelante, al insertar en las tablas finales).
-- =====================================================================
DROP TABLE IF EXISTS stg_sabana;

CREATE TEMP TABLE stg_sabana (
    nombre_organizacion             TEXT,
    sector_organizacion             TEXT,
    pais_organizacion               TEXT,
    tamano_empleados_organizacion   TEXT,
    codigo_brecha                   TEXT,
    fecha_ocurrencia                TEXT,
    fecha_deteccion                 TEXT,
    vector_ataque                   TEXT,
    severidad_incidente             TEXT,
    registros_afectados_total       TEXT,
    costo_estimado_total            TEXT,
    codigo_usuario                  TEXT,
    pseudonimo_usuario              TEXT,
    email_hash_usuario              TEXT,
    pais_residencia_usuario         TEXT,
    fecha_registro_usuario          TEXT,
    tipo_dato_expuesto              TEXT,
    categoria_sensibilidad_dato     TEXT,
    fecha_notificacion_usuario      TEXT
);

-- Encabezado esperado, en el orden exacto que diste.
-- Tabla auxiliar de una sola columna para leer la primera línea cruda
-- de cada archivo (FORMAT text no parte por comas, solo por tab, así
-- que la línea completa entra intacta en una sola celda).
DROP TABLE IF EXISTS _raw_lines;
CREATE TEMP TABLE _raw_lines (linea TEXT);


-- =====================================================================
-- 2. CARGA DE LOS 4 ARCHIVOS, CON VALIDACIÓN DE ENCABEZADO PREVIA
-- =====================================================================

-- ---------- lote_1 ----------
TRUNCATE _raw_lines;
\copy _raw_lines FROM '../../data/sabana_brechas_seguridad_lote_1.csv' WITH (FORMAT text)
DO $$
DECLARE
  encabezado TEXT;
  esperado CONSTANT TEXT :=
    'nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario';
BEGIN
  SELECT linea INTO encabezado FROM _raw_lines LIMIT 1;
  IF encabezado IS DISTINCT FROM esperado THEN
    RAISE EXCEPTION 'lote_1: encabezado no coincide.\nEsperado : %\nEncontrado: %', esperado, encabezado;
  END IF;
END $$;
\copy stg_sabana (nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario) FROM '../../data/sabana_brechas_seguridad_lote_1.csv' WITH (FORMAT csv, HEADER true)

-- ---------- lote_2 ----------
TRUNCATE _raw_lines;
\copy _raw_lines FROM '../../data/sabana_brechas_seguridad_lote_2.csv' WITH (FORMAT text)
DO $$
DECLARE
  encabezado TEXT;
  esperado CONSTANT TEXT :=
    'nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario';
BEGIN
  SELECT linea INTO encabezado FROM _raw_lines LIMIT 1;
  IF encabezado IS DISTINCT FROM esperado THEN
    RAISE EXCEPTION 'lote_2: encabezado no coincide.\nEsperado : %\nEncontrado: %', esperado, encabezado;
  END IF;
END $$;
\copy stg_sabana (nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario) FROM '../../data/sabana_brechas_seguridad_lote_2.csv' WITH (FORMAT csv, HEADER true)

-- ---------- lote_3 ----------
TRUNCATE _raw_lines;
\copy _raw_lines FROM '../../data/sabana_brechas_seguridad_lote_3.csv' WITH (FORMAT text)
DO $$
DECLARE
  encabezado TEXT;
  esperado CONSTANT TEXT :=
    'nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario';
BEGIN
  SELECT linea INTO encabezado FROM _raw_lines LIMIT 1;
  IF encabezado IS DISTINCT FROM esperado THEN
    RAISE EXCEPTION 'lote_3: encabezado no coincide.\nEsperado : %\nEncontrado: %', esperado, encabezado;
  END IF;
END $$;
\copy stg_sabana (nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario) FROM '../../data/sabana_brechas_seguridad_lote_3.csv' WITH (FORMAT csv, HEADER true)

-- ---------- lote_4 ----------
TRUNCATE _raw_lines;
\copy _raw_lines FROM '../../data/sabana_brechas_seguridad_lote_4.csv' WITH (FORMAT text)
DO $$
DECLARE
  encabezado TEXT;
  esperado CONSTANT TEXT :=
    'nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario';
BEGIN
  SELECT linea INTO encabezado FROM _raw_lines LIMIT 1;
  IF encabezado IS DISTINCT FROM esperado THEN
    RAISE EXCEPTION 'lote_4: encabezado no coincide.\nEsperado : %\nEncontrado: %', esperado, encabezado;
  END IF;
END $$;
\copy stg_sabana (nombre_organizacion,sector_organizacion,pais_organizacion,tamano_empleados_organizacion,codigo_brecha,fecha_ocurrencia,fecha_deteccion,vector_ataque,severidad_incidente,registros_afectados_total,costo_estimado_total,codigo_usuario,pseudonimo_usuario,email_hash_usuario,pais_residencia_usuario,fecha_registro_usuario,tipo_dato_expuesto,categoria_sensibilidad_dato,fecha_notificacion_usuario) FROM '../../data/sabana_brechas_seguridad_lote_4.csv' WITH (FORMAT csv, HEADER true)

DROP TABLE _raw_lines;

-- Cuántas filas quedaron en la sábana en total (4 archivos)
SELECT COUNT(*) AS filas_cargadas_en_stg_sabana FROM stg_sabana;


-- =====================================================================
-- 3. VALIDACIÓN DE VALORES ANTES DE NORMALIZAR
-- (evita insertar NULL en nivel_severidad_incidente / nivel_categoria_sensibilidad
-- por una etiqueta que no esperábamos)
-- =====================================================================
DO $$
DECLARE
  desconocidos TEXT;
BEGIN
  SELECT STRING_AGG(DISTINCT severidad_incidente, ', ')
  INTO desconocidos
  FROM stg_sabana
  WHERE severidad_incidente IS NOT NULL
    AND severidad_incidente NOT IN ('Baja','Media','Alta','Crítica','Critica');

  IF desconocidos IS NOT NULL THEN
    RAISE EXCEPTION 'Valores de severidad_incidente no reconocidos (ajusta el mapeo Baja/Media/Alta/Crítica en el script): %', desconocidos;
  END IF;
END $$;

DO $$
DECLARE
  desconocidos TEXT;
BEGIN
  SELECT STRING_AGG(DISTINCT categoria_sensibilidad_dato, ', ')
  INTO desconocidos
  FROM stg_sabana
  WHERE categoria_sensibilidad_dato IS NOT NULL
    AND categoria_sensibilidad_dato NOT IN ('Baja','Media','Alta','Crítica','Critica');

  IF desconocidos IS NOT NULL THEN
    RAISE EXCEPTION 'Valores de categoria_sensibilidad_dato no reconocidos (ajusta el mapeo Baja/Media/Alta/Crítica en el script): %', desconocidos;
  END IF;
END $$;


-- =====================================================================
-- 4. NORMALIZACIÓN -- CATÁLOGOS
-- =====================================================================

INSERT INTO sector_economico (nombre_sector_economico)
SELECT DISTINCT sector_organizacion
FROM stg_sabana
WHERE sector_organizacion IS NOT NULL
ON CONFLICT (nombre_sector_economico) DO NOTHING;

-- pais: unión de país de organización y país de residencia del usuario,
-- ambos apuntan al mismo catálogo.
INSERT INTO pais (nombre_pais)
SELECT DISTINCT p FROM (
    SELECT pais_organizacion AS p FROM stg_sabana
    UNION
    SELECT pais_residencia_usuario AS p FROM stg_sabana
) t
WHERE p IS NOT NULL
ON CONFLICT (nombre_pais) DO NOTHING;

INSERT INTO vector_ataque (nombre_vector_ataque)
SELECT DISTINCT vector_ataque
FROM stg_sabana
WHERE vector_ataque IS NOT NULL
ON CONFLICT (nombre_vector_ataque) DO NOTHING;

INSERT INTO severidad_incidente (nombre_severidad_incidente, nivel_severidad_incidente)
SELECT DISTINCT severidad_incidente,
       CASE severidad_incidente
           WHEN 'Baja'     THEN 1
           WHEN 'Media'    THEN 2
           WHEN 'Alta'     THEN 3
           WHEN 'Crítica'  THEN 4
           WHEN 'Critica'  THEN 4
       END
FROM stg_sabana
WHERE severidad_incidente IS NOT NULL
ON CONFLICT (nombre_severidad_incidente) DO NOTHING;

INSERT INTO categoria_sensibilidad (nombre_categoria_sensibilidad, nivel_categoria_sensibilidad)
SELECT DISTINCT categoria_sensibilidad_dato,
       CASE categoria_sensibilidad_dato
           WHEN 'Baja'     THEN 1
           WHEN 'Media'    THEN 2
           WHEN 'Alta'     THEN 3
           WHEN 'Crítica'  THEN 4
           WHEN 'Critica'  THEN 4
       END
FROM stg_sabana
WHERE categoria_sensibilidad_dato IS NOT NULL
ON CONFLICT (nombre_categoria_sensibilidad) DO NOTHING;

-- Depende de categoria_sensibilidad ya poblada (join para obtener el id)
INSERT INTO tipo_dato_expuesto (nombre_tipo_dato_expuesto, id_categoria_sensibilidad)
SELECT DISTINCT s.tipo_dato_expuesto, c.id_categoria_sensibilidad
FROM stg_sabana s
JOIN categoria_sensibilidad c ON c.nombre_categoria_sensibilidad = s.categoria_sensibilidad_dato
WHERE s.tipo_dato_expuesto IS NOT NULL
ON CONFLICT (nombre_tipo_dato_expuesto) DO NOTHING;


-- =====================================================================
-- 5. NORMALIZACIÓN -- ENTIDADES
-- =====================================================================

-- Supuesto: si el mismo nombre de organización aparece con distinto
-- tamano_empleados en varias filas (inconsistencia de datos), se
-- conserva el primero insertado (ON CONFLICT DO NOTHING descarta el resto).
INSERT INTO organizacion (nombre_organizacion, id_sector_economico, id_pais_organizacion, tamano_empleado_organizacion)
SELECT DISTINCT ON (s.nombre_organizacion)
       s.nombre_organizacion, se.id_sector_economico, p.id_pais,
       s.tamano_empleados_organizacion::INTEGER
FROM stg_sabana s
JOIN sector_economico se ON se.nombre_sector_economico = s.sector_organizacion
JOIN pais p ON p.nombre_pais = s.pais_organizacion
WHERE s.nombre_organizacion IS NOT NULL
ON CONFLICT (nombre_organizacion) DO NOTHING;

INSERT INTO brecha_seguridad (codigo_brecha, id_organizacion, id_vector_ataque, id_severidad_incidente,
       fecha_ocurrencia_brecha, fecha_deteccion_brecha,
       registros_afectados_total_brecha, costo_estimado_total_brecha)
SELECT DISTINCT ON (s.codigo_brecha)
       s.codigo_brecha, o.id_organizacion, va.id_vector_ataque, si.id_severidad_incidente,
       s.fecha_ocurrencia::DATE, s.fecha_deteccion::DATE,
       s.registros_afectados_total::INTEGER, s.costo_estimado_total::NUMERIC(15,2)
FROM stg_sabana s
JOIN organizacion o      ON o.nombre_organizacion = s.nombre_organizacion
JOIN vector_ataque va    ON va.nombre_vector_ataque = s.vector_ataque
JOIN severidad_incidente si ON si.nombre_severidad_incidente = s.severidad_incidente
WHERE s.codigo_brecha IS NOT NULL
ON CONFLICT (codigo_brecha) DO NOTHING;

INSERT INTO usuario (codigo_usuario, pseudonimo_usuario, email_hash_usuario, id_pais_residencia_usuario, id_organizacion, fecha_registro_usuario)
SELECT DISTINCT ON (s.codigo_usuario)
       s.codigo_usuario, s.pseudonimo_usuario, LOWER(s.email_hash_usuario),
       p.id_pais, o.id_organizacion, s.fecha_registro_usuario::DATE
FROM stg_sabana s
JOIN pais p         ON p.nombre_pais = s.pais_residencia_usuario
JOIN organizacion o ON o.nombre_organizacion = s.nombre_organizacion
WHERE s.codigo_usuario IS NOT NULL
ON CONFLICT (codigo_usuario) DO NOTHING;


-- =====================================================================
-- 6. NORMALIZACIÓN -- TABLA PUENTE
-- =====================================================================
INSERT INTO brecha_usuario_tipo_dato (id_brecha_seguridad, id_usuario, id_tipo_dato_expuesto, id_organizacion, fecha_notificacion_usuario)
SELECT DISTINCT
       b.id_brecha_seguridad, u.id_usuario, t.id_tipo_dato_expuesto, o.id_organizacion,
       s.fecha_notificacion_usuario::DATE
FROM stg_sabana s
JOIN organizacion o        ON o.nombre_organizacion = s.nombre_organizacion
JOIN brecha_seguridad b    ON b.codigo_brecha = s.codigo_brecha AND b.id_organizacion = o.id_organizacion
JOIN usuario u             ON u.codigo_usuario = s.codigo_usuario AND u.id_organizacion = o.id_organizacion
JOIN tipo_dato_expuesto t  ON t.nombre_tipo_dato_expuesto = s.tipo_dato_expuesto
ON CONFLICT (id_brecha_seguridad, id_usuario, id_tipo_dato_expuesto) DO NOTHING;


-- =====================================================================
-- 7. LIMPIEZA -- borrar la tabla temporal una vez normalizados los datos
-- =====================================================================
DROP TABLE stg_sabana;

COMMIT;


-- =====================================================================
-- 8. VERIFICACIÓN FINAL (fuera de la transacción)
-- =====================================================================
SELECT 'sector_economico' AS tabla, COUNT(*) FROM sector_economico
UNION ALL SELECT 'pais', COUNT(*) FROM pais
UNION ALL SELECT 'vector_ataque', COUNT(*) FROM vector_ataque
UNION ALL SELECT 'severidad_incidente', COUNT(*) FROM severidad_incidente
UNION ALL SELECT 'categoria_sensibilidad', COUNT(*) FROM categoria_sensibilidad
UNION ALL SELECT 'tipo_dato_expuesto', COUNT(*) FROM tipo_dato_expuesto
UNION ALL SELECT 'organizacion', COUNT(*) FROM organizacion
UNION ALL SELECT 'brecha_seguridad', COUNT(*) FROM brecha_seguridad
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'brecha_usuario_tipo_dato', COUNT(*) FROM brecha_usuario_tipo_dato;

-- Fin del script 02
