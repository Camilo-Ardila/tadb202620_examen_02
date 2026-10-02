-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 02: carga de datos (sábana consolidada -> modelo normalizado)
-- Motor   : MySQL 8.4 (contenedor Docker tadb_ex02_mysql, puerto 3307)
-- Autores : Camilo José Ardila Restrepo - ID 000543367
--           David Berrío Martínez       - ID 000547257
-- Archivo : UTF-8, texto plano
--
-- Requisito: haber ejecutado 01_implementacion_modelo_brechas_mysql.sql
--
-- Contenido:
--   0. Limpieza de cargas anteriores (permite re-ejecutar el script)
--   1. Tabla de staging con la sábana tal como viene en los CSV
--   2. Lectura de los 4 lotes CSV (40,000 filas)
--   3. Poblamiento del modelo: catálogos -> entidades -> tabla puente
--   4. Validación de la carga
--   5. Eliminación del staging y actualización de estadísticas
--
-- Ejecución: conectado como root desde DBeaver, en una conexión con la
-- propiedad allowLoadLocalInfile=true. Ejecutar como SCRIPT COMPLETO con
-- Alt+X, sin texto seleccionado. DBeaver pedirá confirmar los TRUNCATE y
-- el DROP TABLE: aceptar.
-- =====================================================================

USE brechas_seguridad;


-- =====================================================================
-- 0. LIMPIEZA DE CARGAS ANTERIORES
-- TRUNCATE vacía cada tabla y reinicia su AUTO_INCREMENT en 1. Se
-- desactiva temporalmente la verificación de FK solo para poder vaciar
-- las tablas padre; el orden de carga posterior la respeta.
-- =====================================================================
DROP TABLE IF EXISTS stg_sabana_brechas;

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE brecha_usuario_tipo_dato;

TRUNCATE TABLE usuario;

TRUNCATE TABLE brecha_seguridad;

TRUNCATE TABLE organizacion;

TRUNCATE TABLE tipo_dato_expuesto;

TRUNCATE TABLE categoria_sensibilidad;

TRUNCATE TABLE severidad_incidente;

TRUNCATE TABLE vector_ataque;

TRUNCATE TABLE pais;

TRUNCATE TABLE sector_economico;

SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- 1. TABLA DE STAGING
-- Una columna por cada columna del CSV, todas como texto, para recibir
-- la sábana sin transformaciones. Los tipos de dato definitivos se
-- aplican al pasar los datos al modelo (paso 3).
-- =====================================================================
CREATE TABLE stg_sabana_brechas (
    nombre_organizacion           VARCHAR(100),
    sector_organizacion           VARCHAR(50),
    pais_organizacion             VARCHAR(50),
    tamano_empleados_organizacion VARCHAR(20),
    codigo_brecha                 VARCHAR(10),
    fecha_ocurrencia              VARCHAR(10),
    fecha_deteccion               VARCHAR(10),
    vector_ataque                 VARCHAR(50),
    severidad_incidente           VARCHAR(20),
    registros_afectados_total     VARCHAR(20),
    costo_estimado_total          VARCHAR(20),
    codigo_usuario                VARCHAR(10),
    pseudonimo_usuario            VARCHAR(50),
    email_hash_usuario            VARCHAR(32),
    pais_residencia_usuario       VARCHAR(50),
    fecha_registro_usuario        VARCHAR(10),
    tipo_dato_expuesto            VARCHAR(50),
    categoria_sensibilidad_dato   VARCHAR(20),
    fecha_notificacion_usuario    VARCHAR(10)
) ENGINE = InnoDB;


-- =====================================================================
-- 2. LECTURA DE LOS CSV
-- LOAD DATA LOCAL INFILE: DBeaver lee cada archivo desde Windows y lo
-- envía al servidor (requiere local_infile=1 en el servidor, definido en
-- el docker-compose.yml, y allowLoadLocalInfile=true en la conexión).
--   - Campos separados por coma; algunos nombres de organización vienen
--     entre comillas porque contienen comas ("Cline, Hampton and Perez").
--   - Fin de línea: se separa por \n y se elimina el \r final de la
--     última columna, así funciona tanto con archivos guardados con fin
--     de línea de Windows (\r\n) como de Linux/Git (\n).
--   - IGNORE 1 LINES omite la fila de encabezados.
-- >>> Ajuste la ruta si el repositorio está en otra ubicación. <<<
-- =====================================================================
LOAD DATA LOCAL INFILE 'C:/Users/david/Desktop/semestre6/topicos_en_bd/tadb202620_examen_02/data/sabana_brechas_seguridad_lote_1.csv'
INTO TABLE stg_sabana_brechas
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(nombre_organizacion, sector_organizacion, pais_organizacion, tamano_empleados_organizacion,
 codigo_brecha, fecha_ocurrencia, fecha_deteccion, vector_ataque, severidad_incidente,
 registros_afectados_total, costo_estimado_total, codigo_usuario, pseudonimo_usuario,
 email_hash_usuario, pais_residencia_usuario, fecha_registro_usuario, tipo_dato_expuesto,
 categoria_sensibilidad_dato, @fecha_notificacion)
SET fecha_notificacion_usuario = TRIM(TRAILING '\r' FROM @fecha_notificacion);

LOAD DATA LOCAL INFILE 'C:/Users/david/Desktop/semestre6/topicos_en_bd/tadb202620_examen_02/data/sabana_brechas_seguridad_lote_2.csv'
INTO TABLE stg_sabana_brechas
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(nombre_organizacion, sector_organizacion, pais_organizacion, tamano_empleados_organizacion,
 codigo_brecha, fecha_ocurrencia, fecha_deteccion, vector_ataque, severidad_incidente,
 registros_afectados_total, costo_estimado_total, codigo_usuario, pseudonimo_usuario,
 email_hash_usuario, pais_residencia_usuario, fecha_registro_usuario, tipo_dato_expuesto,
 categoria_sensibilidad_dato, @fecha_notificacion)
SET fecha_notificacion_usuario = TRIM(TRAILING '\r' FROM @fecha_notificacion);

LOAD DATA LOCAL INFILE 'C:/Users/david/Desktop/semestre6/topicos_en_bd/tadb202620_examen_02/data/sabana_brechas_seguridad_lote_3.csv'
INTO TABLE stg_sabana_brechas
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(nombre_organizacion, sector_organizacion, pais_organizacion, tamano_empleados_organizacion,
 codigo_brecha, fecha_ocurrencia, fecha_deteccion, vector_ataque, severidad_incidente,
 registros_afectados_total, costo_estimado_total, codigo_usuario, pseudonimo_usuario,
 email_hash_usuario, pais_residencia_usuario, fecha_registro_usuario, tipo_dato_expuesto,
 categoria_sensibilidad_dato, @fecha_notificacion)
SET fecha_notificacion_usuario = TRIM(TRAILING '\r' FROM @fecha_notificacion);

LOAD DATA LOCAL INFILE 'C:/Users/david/Desktop/semestre6/topicos_en_bd/tadb202620_examen_02/data/sabana_brechas_seguridad_lote_4.csv'
INTO TABLE stg_sabana_brechas
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(nombre_organizacion, sector_organizacion, pais_organizacion, tamano_empleados_organizacion,
 codigo_brecha, fecha_ocurrencia, fecha_deteccion, vector_ataque, severidad_incidente,
 registros_afectados_total, costo_estimado_total, codigo_usuario, pseudonimo_usuario,
 email_hash_usuario, pais_residencia_usuario, fecha_registro_usuario, tipo_dato_expuesto,
 categoria_sensibilidad_dato, @fecha_notificacion)
SET fecha_notificacion_usuario = TRIM(TRAILING '\r' FROM @fecha_notificacion);

-- Debe devolver 40000
SELECT COUNT(*) AS filas_staging FROM stg_sabana_brechas;


-- =====================================================================
-- 3. POBLAMIENTO DEL MODELO
-- Orden: primero las tablas padre (catálogos), luego las entidades y por
-- último la tabla puente, para que cada FK encuentre su referencia.
-- Cada INSERT ... SELECT DISTINCT extrae de la sábana una sola fila por
-- cada valor distinto (eso es la normalización) y traduce los nombres a
-- las llaves subrogadas mediante JOIN con las tablas ya cargadas.
-- =====================================================================

-- 3.1 Catálogos ------------------------------------------------------

INSERT INTO sector_economico (nombre_sector_economico)
SELECT DISTINCT sector_organizacion
  FROM stg_sabana_brechas
 ORDER BY sector_organizacion;

-- El catálogo de países une los países de las organizaciones y los de
-- residencia de los usuarios (UNION elimina repetidos).
INSERT INTO pais (nombre_pais)
SELECT nombre
  FROM (SELECT pais_organizacion AS nombre FROM stg_sabana_brechas
        UNION
        SELECT pais_residencia_usuario FROM stg_sabana_brechas) p
 ORDER BY nombre;

INSERT INTO vector_ataque (nombre_vector_ataque)
SELECT DISTINCT vector_ataque
  FROM stg_sabana_brechas
 ORDER BY vector_ataque;

-- El nivel numérico no viene en la sábana: se asigna según el nombre.
INSERT INTO severidad_incidente (nombre_severidad_incidente, nivel_severidad_incidente)
SELECT s.severidad_incidente,
       CASE s.severidad_incidente
            WHEN 'Baja'    THEN 1
            WHEN 'Media'   THEN 2
            WHEN 'Alta'    THEN 3
            WHEN 'Critica' THEN 4
       END AS nivel
  FROM (SELECT DISTINCT severidad_incidente FROM stg_sabana_brechas) s
 ORDER BY nivel;

INSERT INTO categoria_sensibilidad (nombre_categoria_sensibilidad, nivel_categoria_sensibilidad)
SELECT c.categoria_sensibilidad_dato,
       CASE c.categoria_sensibilidad_dato
            WHEN 'Baja'    THEN 1
            WHEN 'Media'   THEN 2
            WHEN 'Alta'    THEN 3
            WHEN 'Critica' THEN 4
       END AS nivel
  FROM (SELECT DISTINCT categoria_sensibilidad_dato FROM stg_sabana_brechas) c
 ORDER BY nivel;

-- 3.2 Entidades ------------------------------------------------------

INSERT INTO tipo_dato_expuesto (nombre_tipo_dato_expuesto, id_categoria_sensibilidad)
SELECT DISTINCT s.tipo_dato_expuesto, c.id_categoria_sensibilidad
  FROM stg_sabana_brechas s
  JOIN categoria_sensibilidad c
    ON c.nombre_categoria_sensibilidad = s.categoria_sensibilidad_dato
 ORDER BY s.tipo_dato_expuesto;

INSERT INTO organizacion (nombre_organizacion, id_sector_economico,
                          id_pais_organizacion, tamano_empleado_organizacion)
SELECT DISTINCT s.nombre_organizacion,
       se.id_sector_economico,
       p.id_pais,
       CAST(s.tamano_empleados_organizacion AS UNSIGNED)
  FROM stg_sabana_brechas s
  JOIN sector_economico se ON se.nombre_sector_economico = s.sector_organizacion
  JOIN pais p              ON p.nombre_pais = s.pais_organizacion
 ORDER BY s.nombre_organizacion;

INSERT INTO brecha_seguridad (codigo_brecha, id_organizacion, id_vector_ataque,
                              id_severidad_incidente, fecha_ocurrencia_brecha,
                              fecha_deteccion_brecha, registros_afectados_total_brecha,
                              costo_estimado_total_brecha)
SELECT DISTINCT s.codigo_brecha,
       o.id_organizacion,
       v.id_vector_ataque,
       sv.id_severidad_incidente,
       CAST(s.fecha_ocurrencia AS DATE),
       CAST(s.fecha_deteccion AS DATE),
       CAST(s.registros_afectados_total AS UNSIGNED),
       CAST(s.costo_estimado_total AS DECIMAL(15,2))
  FROM stg_sabana_brechas s
  JOIN organizacion o         ON o.nombre_organizacion = s.nombre_organizacion
  JOIN vector_ataque v        ON v.nombre_vector_ataque = s.vector_ataque
  JOIN severidad_incidente sv ON sv.nombre_severidad_incidente = s.severidad_incidente
 ORDER BY s.codigo_brecha;

-- La organización del usuario es la organización de las filas en que
-- aparece (en los datos, cada usuario pertenece a una sola).
INSERT INTO usuario (codigo_usuario, pseudonimo_usuario, email_hash_usuario,
                     id_pais_residencia_usuario, id_organizacion, fecha_registro_usuario)
SELECT DISTINCT s.codigo_usuario,
       s.pseudonimo_usuario,
       s.email_hash_usuario,
       p.id_pais,
       o.id_organizacion,
       CAST(s.fecha_registro_usuario AS DATE)
  FROM stg_sabana_brechas s
  JOIN pais p         ON p.nombre_pais = s.pais_residencia_usuario
  JOIN organizacion o ON o.nombre_organizacion = s.nombre_organizacion
 ORDER BY s.codigo_usuario;

-- 3.3 Tabla puente ---------------------------------------------------
-- id_organizacion se toma de la brecha. Las FK compuestas verifican en
-- cada fila que esa organización sea también la del usuario: si alguna
-- fila no cumpliera, el INSERT completo fallaría.
INSERT INTO brecha_usuario_tipo_dato (id_brecha_seguridad, id_usuario, id_tipo_dato_expuesto,
                                      id_organizacion, fecha_notificacion_usuario)
SELECT b.id_brecha_seguridad,
       u.id_usuario,
       t.id_tipo_dato_expuesto,
       b.id_organizacion,
       CAST(s.fecha_notificacion_usuario AS DATE)
  FROM stg_sabana_brechas s
  JOIN brecha_seguridad b   ON b.codigo_brecha = s.codigo_brecha
  JOIN usuario u            ON u.codigo_usuario = s.codigo_usuario
  JOIN tipo_dato_expuesto t ON t.nombre_tipo_dato_expuesto = s.tipo_dato_expuesto;


-- =====================================================================
-- 4. VALIDACIÓN DE LA CARGA
-- =====================================================================

-- 4.1 Conteo por tabla contra los valores del enunciado
SELECT 'sector_economico'         AS tabla, COUNT(*) AS registros, NULL  AS esperado FROM sector_economico
UNION ALL SELECT 'pais',                     COUNT(*),              NULL              FROM pais
UNION ALL SELECT 'vector_ataque',            COUNT(*),              NULL              FROM vector_ataque
UNION ALL SELECT 'severidad_incidente',      COUNT(*),              4                 FROM severidad_incidente
UNION ALL SELECT 'categoria_sensibilidad',   COUNT(*),              4                 FROM categoria_sensibilidad
UNION ALL SELECT 'tipo_dato_expuesto',       COUNT(*),              10                FROM tipo_dato_expuesto
UNION ALL SELECT 'organizacion',             COUNT(*),              60                FROM organizacion
UNION ALL SELECT 'brecha_seguridad',         COUNT(*),              800               FROM brecha_seguridad
UNION ALL SELECT 'usuario',                  COUNT(*),              7887              FROM usuario
UNION ALL SELECT 'brecha_usuario_tipo_dato', COUNT(*),              40000             FROM brecha_usuario_tipo_dato;

-- 4.2 Regla de la nota 5 del diagrama: la notificación no puede ser
-- anterior a la detección de la brecha. Debe devolver 0.
SELECT COUNT(*) AS notificaciones_antes_de_deteccion
  FROM brecha_usuario_tipo_dato x
  JOIN brecha_seguridad b ON b.id_brecha_seguridad = x.id_brecha_seguridad
 WHERE x.fecha_notificacion_usuario < b.fecha_deteccion_brecha;

-- 4.3 Regla de la nota 2 del diagrama (garantizada por las FK
-- compuestas): organización de la brecha = organización del usuario.
-- Debe devolver 0.
SELECT COUNT(*) AS filas_con_organizacion_distinta
  FROM brecha_usuario_tipo_dato x
  JOIN usuario u          ON u.id_usuario = x.id_usuario
  JOIN brecha_seguridad b ON b.id_brecha_seguridad = x.id_brecha_seguridad
 WHERE u.id_organizacion <> b.id_organizacion;

-- 4.4 Regla de la nota 4 del diagrama (1..N): toda brecha y todo usuario
-- tienen al menos una fila en la tabla puente. Ambos deben devolver 0.
SELECT COUNT(*) AS brechas_sin_exposicion
  FROM brecha_seguridad b
 WHERE NOT EXISTS (SELECT 1 FROM brecha_usuario_tipo_dato x
                    WHERE x.id_brecha_seguridad = b.id_brecha_seguridad);

SELECT COUNT(*) AS usuarios_sin_exposicion
  FROM usuario u
 WHERE NOT EXISTS (SELECT 1 FROM brecha_usuario_tipo_dato x
                    WHERE x.id_usuario = u.id_usuario);

-- 4.5 Muestra de la sábana reconstruida a partir del modelo
SELECT o.nombre_organizacion, b.codigo_brecha, b.fecha_deteccion_brecha,
       u.codigo_usuario, t.nombre_tipo_dato_expuesto,
       c.nombre_categoria_sensibilidad, x.fecha_notificacion_usuario
  FROM brecha_usuario_tipo_dato x
  JOIN brecha_seguridad b       ON b.id_brecha_seguridad = x.id_brecha_seguridad
  JOIN organizacion o           ON o.id_organizacion = x.id_organizacion
  JOIN usuario u                ON u.id_usuario = x.id_usuario
  JOIN tipo_dato_expuesto t     ON t.id_tipo_dato_expuesto = x.id_tipo_dato_expuesto
  JOIN categoria_sensibilidad c ON c.id_categoria_sensibilidad = t.id_categoria_sensibilidad
 ORDER BY b.codigo_brecha, u.codigo_usuario
 LIMIT 20;


-- =====================================================================
-- 5. CIERRE
-- =====================================================================

-- La sábana ya fue normalizada: se elimina el staging para que el
-- esquema contenga únicamente las 10 tablas del modelo.
DROP TABLE stg_sabana_brechas;

-- Actualiza las estadísticas que usa el optimizador para estimar filas
-- y costos en los planes de ejecución (etapas 3 y 4).
ANALYZE TABLE sector_economico, pais, vector_ataque, severidad_incidente,
              categoria_sensibilidad, tipo_dato_expuesto, organizacion,
              brecha_seguridad, usuario, brecha_usuario_tipo_dato;

-- Fin del script 02
