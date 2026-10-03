-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 01: implementación del modelo de datos (diagrama relacional)
-- Motor   : MySQL 8.4 (contenedor Docker tadb_ex02_mysql, puerto 3307)
-- Autores : Camilo José Ardila Restrepo - ID 000543367
--           David Berrío Martínez       - ID 000547257
-- Archivo : UTF-8, texto plano
--
-- Contenido:
--   0. Limpieza de ejecuciones anteriores
--   1. Creación del esquema y de los usuarios
--   2. Nota sobre secuencias en MySQL
--   3. Tablas de catálogo
--   4. Tablas de entidades
--   5. Tabla puente
--   6. Asignación de privilegios mínimos
--   7. Verificación
--
-- Las funciones, procedimientos, vistas y la carga de datos se
-- implementan en el script 02.
--
-- Ejecución: conectado como root desde DBeaver. Ejecutar como SCRIPT
-- COMPLETO con Alt+X (Editor SQL -> Ejecutar script SQL), sin texto
-- seleccionado.
-- =====================================================================


-- =====================================================================
-- 0. LIMPIEZA
-- Elimina el esquema completo de ejecuciones anteriores (tablas, datos,
-- índices, vistas, funciones, procedimientos y triggers) y los usuarios.
-- Permite re-ejecutar el script desde cero.
-- =====================================================================
DROP DATABASE IF EXISTS brechas_seguridad;

DROP USER IF EXISTS 'brechas_owner'@'%';

DROP USER IF EXISTS 'brechas_app'@'%';


-- =====================================================================
-- 1. ESQUEMA Y USUARIOS
-- En MySQL "esquema" y "base de datos" son sinónimos.
-- =====================================================================
CREATE DATABASE brechas_seguridad
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

-- Usuario dueño del esquema: administra los objetos de brechas_seguridad
-- y nada más (sin privilegios globales sobre el servidor).
CREATE USER 'brechas_owner'@'%' IDENTIFIED BY 'OwnerBrechas2026*';

-- Usuario de aplicación / consultas: solo lectura (privilegios mínimos).
CREATE USER 'brechas_app'@'%' IDENTIFIED BY 'AppBrechas2026*';

USE brechas_seguridad;


-- =====================================================================
-- 2. SECUENCIAS
-- MySQL no implementa el objeto SEQUENCE (a diferencia de PostgreSQL u
-- Oracle). El equivalente es el atributo AUTO_INCREMENT, que genera la
-- llave subrogada de forma secuencial en cada tabla. Todas las llaves
-- primarias subrogadas del modelo usan AUTO_INCREMENT.
-- =====================================================================


-- =====================================================================
-- 3. TABLAS DE CATÁLOGO (azul en el diagrama)
-- =====================================================================

-- Sector económico de la organización
CREATE TABLE sector_economico (
    id_sector_economico     SMALLINT    NOT NULL AUTO_INCREMENT,
    nombre_sector_economico VARCHAR(50) NOT NULL,
    CONSTRAINT pk_sector_economico PRIMARY KEY (id_sector_economico),
    CONSTRAINT uq_sector_economico_nombre UNIQUE (nombre_sector_economico)
) ENGINE = InnoDB;

-- País: lo usan la organización (sede) y el usuario (residencia)
CREATE TABLE pais (
    id_pais     SMALLINT    NOT NULL AUTO_INCREMENT,
    nombre_pais VARCHAR(50) NOT NULL,
    CONSTRAINT pk_pais PRIMARY KEY (id_pais),
    CONSTRAINT uq_pais_nombre UNIQUE (nombre_pais)
) ENGINE = InnoDB;

-- Vector de ataque de la brecha (phishing, ransomware, ...)
CREATE TABLE vector_ataque (
    id_vector_ataque     SMALLINT    NOT NULL AUTO_INCREMENT,
    nombre_vector_ataque VARCHAR(50) NOT NULL,
    CONSTRAINT pk_vector_ataque PRIMARY KEY (id_vector_ataque),
    CONSTRAINT uq_vector_ataque_nombre UNIQUE (nombre_vector_ataque)
) ENGINE = InnoDB;

-- Severidad del incidente. El nivel (1 = Baja ... 4 = Crítica) permite
-- filtrar por rango: "alta o crítica" = nivel >= 3.
CREATE TABLE severidad_incidente (
    id_severidad_incidente     SMALLINT    NOT NULL AUTO_INCREMENT,
    nombre_severidad_incidente VARCHAR(20) NOT NULL,
    nivel_severidad_incidente  SMALLINT    NOT NULL,
    CONSTRAINT pk_severidad_incidente PRIMARY KEY (id_severidad_incidente),
    CONSTRAINT uq_severidad_incidente_nombre UNIQUE (nombre_severidad_incidente),
    CONSTRAINT uq_severidad_incidente_nivel UNIQUE (nivel_severidad_incidente),
    CONSTRAINT ck_severidad_incidente_nivel CHECK (nivel_severidad_incidente BETWEEN 1 AND 4)
) ENGINE = InnoDB;

-- Categoría de sensibilidad del dato (1 = Baja ... 4 = Crítica)
CREATE TABLE categoria_sensibilidad (
    id_categoria_sensibilidad     SMALLINT    NOT NULL AUTO_INCREMENT,
    nombre_categoria_sensibilidad VARCHAR(20) NOT NULL,
    nivel_categoria_sensibilidad  SMALLINT    NOT NULL,
    CONSTRAINT pk_categoria_sensibilidad PRIMARY KEY (id_categoria_sensibilidad),
    CONSTRAINT uq_categoria_sensibilidad_nombre UNIQUE (nombre_categoria_sensibilidad),
    CONSTRAINT uq_categoria_sensibilidad_nivel UNIQUE (nivel_categoria_sensibilidad),
    CONSTRAINT ck_categoria_sensibilidad_nivel CHECK (nivel_categoria_sensibilidad BETWEEN 1 AND 4)
) ENGINE = InnoDB;


-- =====================================================================
-- 4. TABLAS DE ENTIDADES (verde en el diagrama)
-- Cada FK lleva su índice declarado con nombre propio (InnoDB exige un
-- índice cuyas primeras columnas sean las de la FK).
-- =====================================================================

-- Tipo de dato expuesto: catálogo fijo de 10 tipos con su categoría
CREATE TABLE tipo_dato_expuesto (
    id_tipo_dato_expuesto     SMALLINT    NOT NULL AUTO_INCREMENT,
    nombre_tipo_dato_expuesto VARCHAR(50) NOT NULL,
    id_categoria_sensibilidad SMALLINT    NOT NULL,
    CONSTRAINT pk_tipo_dato_expuesto PRIMARY KEY (id_tipo_dato_expuesto),
    CONSTRAINT uq_tipo_dato_expuesto_nombre UNIQUE (nombre_tipo_dato_expuesto),
    -- Etapa 3: ubica los tipos de dato de categoría crítica
    INDEX idx_tipo_dato_categoria (id_categoria_sensibilidad),
    CONSTRAINT fk_tipo_dato_categoria FOREIGN KEY (id_categoria_sensibilidad)
        REFERENCES categoria_sensibilidad (id_categoria_sensibilidad)
) ENGINE = InnoDB;

-- Organización afectada
CREATE TABLE organizacion (
    id_organizacion              INTEGER      NOT NULL AUTO_INCREMENT,
    nombre_organizacion          VARCHAR(100) NOT NULL,
    id_sector_economico          SMALLINT     NOT NULL,
    id_pais_organizacion         SMALLINT     NOT NULL,
    tamano_empleado_organizacion INTEGER      NOT NULL,
    CONSTRAINT pk_organizacion PRIMARY KEY (id_organizacion),
    CONSTRAINT uq_organizacion_nombre UNIQUE (nombre_organizacion),
    INDEX idx_organizacion_sector (id_sector_economico),
    INDEX idx_organizacion_pais (id_pais_organizacion),
    CONSTRAINT fk_organizacion_sector FOREIGN KEY (id_sector_economico)
        REFERENCES sector_economico (id_sector_economico),
    CONSTRAINT fk_organizacion_pais FOREIGN KEY (id_pais_organizacion)
        REFERENCES pais (id_pais),
    CONSTRAINT ck_organizacion_tamano CHECK (tamano_empleado_organizacion > 0)
) ENGINE = InnoDB;

-- Brecha de seguridad, asociada a una organización.
-- UQ1 (id_brecha_seguridad, id_organizacion): unicidad compuesta que
-- permite a la tabla puente referenciar la pareja (brecha, organización).
CREATE TABLE brecha_seguridad (
    id_brecha_seguridad              INTEGER       NOT NULL AUTO_INCREMENT,
    codigo_brecha                    VARCHAR(10)   NOT NULL,
    id_organizacion                  INTEGER       NOT NULL,
    id_vector_ataque                 SMALLINT      NOT NULL,
    id_severidad_incidente           SMALLINT      NOT NULL,
    fecha_ocurrencia_brecha          DATE          NOT NULL,
    fecha_deteccion_brecha           DATE          NOT NULL,
    registros_afectados_total_brecha INTEGER       NOT NULL,
    costo_estimado_total_brecha      DECIMAL(15,2) NOT NULL,
    CONSTRAINT pk_brecha_seguridad PRIMARY KEY (id_brecha_seguridad),
    CONSTRAINT uq_brecha_seguridad_codigo UNIQUE (codigo_brecha),
    CONSTRAINT uq1_brecha_seguridad_organizacion UNIQUE (id_brecha_seguridad, id_organizacion),
    INDEX idx_brecha_organizacion (id_organizacion),
    INDEX idx_brecha_vector (id_vector_ataque),
    INDEX idx_brecha_severidad (id_severidad_incidente),
    CONSTRAINT fk_brecha_organizacion FOREIGN KEY (id_organizacion)
        REFERENCES organizacion (id_organizacion),
    CONSTRAINT fk_brecha_vector FOREIGN KEY (id_vector_ataque)
        REFERENCES vector_ataque (id_vector_ataque),
    CONSTRAINT fk_brecha_severidad FOREIGN KEY (id_severidad_incidente)
        REFERENCES severidad_incidente (id_severidad_incidente),
    CONSTRAINT ck_brecha_fechas CHECK (fecha_deteccion_brecha >= fecha_ocurrencia_brecha),
    CONSTRAINT ck_brecha_registros CHECK (registros_afectados_total_brecha >= 0),
    CONSTRAINT ck_brecha_costo CHECK (costo_estimado_total_brecha >= 0)
) ENGINE = InnoDB;

-- Usuario cuya información fue expuesta. Identificación seudonimizada:
-- código, pseudónimo y hash MD5 del correo.
-- UQ1 (id_usuario, id_organizacion): unicidad compuesta que permite a la
-- tabla puente referenciar la pareja (usuario, organización).
CREATE TABLE usuario (
    id_usuario                 INTEGER     NOT NULL AUTO_INCREMENT,
    codigo_usuario             VARCHAR(10) NOT NULL,
    pseudonimo_usuario         VARCHAR(50) NOT NULL,
    email_hash_usuario         CHAR(32)    NOT NULL,
    id_pais_residencia_usuario SMALLINT    NOT NULL,
    id_organizacion            INTEGER     NOT NULL,
    fecha_registro_usuario     DATE        NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_codigo UNIQUE (codigo_usuario),
    CONSTRAINT uq_usuario_pseudonimo UNIQUE (pseudonimo_usuario),
    CONSTRAINT uq_usuario_email_hash UNIQUE (email_hash_usuario),
    CONSTRAINT uq1_usuario_organizacion UNIQUE (id_usuario, id_organizacion),
    INDEX idx_usuario_pais (id_pais_residencia_usuario),
    INDEX idx_usuario_organizacion (id_organizacion),
    CONSTRAINT fk_usuario_pais FOREIGN KEY (id_pais_residencia_usuario)
        REFERENCES pais (id_pais),
    CONSTRAINT fk_usuario_organizacion FOREIGN KEY (id_organizacion)
        REFERENCES organizacion (id_organizacion),
    CONSTRAINT ck_usuario_email_hash CHECK (REGEXP_LIKE(email_hash_usuario, '^[0-9a-f]{32}$', 'c'))
) ENGINE = InnoDB;


-- =====================================================================
-- 5. TABLA PUENTE (naranja en el diagrama)
-- Relación muchos a muchos entre brecha, usuario y tipo de dato. Cada
-- fila: "en la brecha X, al usuario Y se le expuso el dato Z y fue
-- notificado en la fecha F".
--
-- id_organizacion se repite intencionalmente: las dos FK compuestas
-- (brecha, organización) y (usuario, organización) obligan a que la
-- organización de la brecha y la del usuario sean la misma.
-- =====================================================================
CREATE TABLE brecha_usuario_tipo_dato (
    id_brecha_seguridad        INTEGER  NOT NULL,
    id_usuario                 INTEGER  NOT NULL,
    id_tipo_dato_expuesto      SMALLINT NOT NULL,
    id_organizacion            INTEGER  NOT NULL,
    fecha_notificacion_usuario DATE     NOT NULL,
    CONSTRAINT pk_brecha_usuario_tipo_dato
        PRIMARY KEY (id_brecha_seguridad, id_usuario, id_tipo_dato_expuesto),

    -- Soporte de la FK compuesta hacia la brecha
    INDEX idx_butd_brecha_organizacion (id_brecha_seguridad, id_organizacion),

    -- Soporte de la FK compuesta hacia el usuario y, además, índice de
    -- desempeño de la Etapa 4 (historial de un usuario ordenado por fecha
    -- de notificación). InnoDB agrega la PK a cada entrada de un índice
    -- secundario, así que este índice cubre la consulta sin leer la tabla.
    INDEX idx_butd_usuario_org_fecha (id_usuario, id_organizacion, fecha_notificacion_usuario),

    -- Soporte de la FK hacia el tipo de dato y, además, índice de
    -- desempeño de la Etapa 3: con la PK agregada equivale a
    -- (tipo, brecha, usuario) y resuelve "la brecha expuso un dato
    -- crítico" sin leer la tabla.
    INDEX idx_butd_tipo_dato (id_tipo_dato_expuesto),

    CONSTRAINT fk_butd_brecha_organizacion FOREIGN KEY (id_brecha_seguridad, id_organizacion)
        REFERENCES brecha_seguridad (id_brecha_seguridad, id_organizacion),
    CONSTRAINT fk_butd_usuario_organizacion FOREIGN KEY (id_usuario, id_organizacion)
        REFERENCES usuario (id_usuario, id_organizacion),
    CONSTRAINT fk_butd_tipo_dato FOREIGN KEY (id_tipo_dato_expuesto)
        REFERENCES tipo_dato_expuesto (id_tipo_dato_expuesto)
) ENGINE = InnoDB
  -- Muestreo amplio para que ANALYZE TABLE obtenga estadísticas estables
  -- (el optimizador las usa para estimar filas y costo de los planes).
  STATS_SAMPLE_PAGES = 1000;


-- =====================================================================
-- 6. PRIVILEGIOS MÍNIMOS
-- =====================================================================

-- Dueño del esquema: objetos y datos únicamente de brechas_seguridad
GRANT SELECT, INSERT, UPDATE, DELETE,
      CREATE, ALTER, DROP, INDEX, REFERENCES,
      CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE,
      EXECUTE, TRIGGER
   ON brechas_seguridad.* TO 'brechas_owner'@'%';

-- Aplicación / consultas: solo lectura de las tablas del modelo.
-- (Los permisos sobre vistas y rutinas se otorgan en el script 02.)
GRANT SELECT ON brechas_seguridad.sector_economico         TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.pais                     TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.vector_ataque            TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.severidad_incidente      TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.categoria_sensibilidad   TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.tipo_dato_expuesto       TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.organizacion             TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.brecha_seguridad         TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.usuario                  TO 'brechas_app'@'%';

GRANT SELECT ON brechas_seguridad.brecha_usuario_tipo_dato TO 'brechas_app'@'%';


-- =====================================================================
-- 7. VERIFICACIÓN
-- =====================================================================

-- Tablas creadas (deben ser 10)
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'brechas_seguridad'
 ORDER BY table_name;

-- Llaves foráneas (incluidas las dos compuestas de la tabla puente)
SELECT table_name, constraint_name,
       GROUP_CONCAT(column_name ORDER BY ordinal_position) AS columnas,
       referenced_table_name
  FROM information_schema.key_column_usage
 WHERE table_schema = 'brechas_seguridad'
   AND referenced_table_name IS NOT NULL
 GROUP BY table_name, constraint_name, referenced_table_name
 ORDER BY table_name, constraint_name;

SHOW GRANTS FOR 'brechas_owner'@'%';

SHOW GRANTS FOR 'brechas_app'@'%';

-- Fin del script 01
