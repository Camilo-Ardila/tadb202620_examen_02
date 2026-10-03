-- =====================================================================
-- Universidad Pontificia Bolivariana
-- Tópicos Avanzados de Bases de Datos - Periodo 202620
-- Examen No. 2 - Índices y Mejoras en el Desempeño de Consultas
-- Dominio: Análisis de Brechas de Seguridad
--
-- Script 00: creación de la base de datos y los roles (PostgreSQL)
-- Motor   : PostgreSQL 17 (Amazon RDS)
--
-- IMPORTANTE: este script se ejecuta conectado a la base de
-- mantenimiento "postgres" (o cualquier otra que NO sea
-- brechas_seguridad), porque CREATE DATABASE / DROP DATABASE no
-- pueden correr dentro de la misma transacción que otras sentencias,
-- ni mientras haya otra sesión conectada a la base que se va a borrar.
--
-- En Beekeeper Studio: conéctate primero con "Default Database" =
-- postgres, corre este archivo completo, y LUEGO crea una conexión
-- nueva (o cambia la base por defecto) a "brechas_seguridad" para
-- correr el script 01.
-- =====================================================================


-- =====================================================================
-- 0. LIMPIEZA (permite re-ejecutar desde cero)
-- =====================================================================

-- Corta cualquier sesión activa contra brechas_seguridad; si no, el
-- DROP DATABASE de abajo falla con "database is being accessed by
-- other users".
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'brechas_seguridad'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS brechas_seguridad;

-- Los roles de PostgreSQL son a nivel de clúster (no por base de
-- datos), por eso se crean/eliminan desde aquí.
DROP ROLE IF EXISTS brechas_camilo;
DROP ROLE IF EXISTS brechas_david;
DROP ROLE IF EXISTS brechas_owner_role;


-- =====================================================================
-- 1. BASE DE DATOS
-- PostgreSQL en RDS ya usa UTF8 por defecto a nivel de instancia, así
-- que no hace falta especificar CHARACTER SET/COLLATE como en MySQL.
-- =====================================================================
CREATE DATABASE brechas_seguridad;


-- =====================================================================
-- 2. ROLES
--
-- brechas_owner_role: rol SIN LOGIN que servirá como "dueño" del
--   esquema y las tablas. En PostgreSQL, crear un índice (CREATE
--   INDEX) exige ser dueño de la tabla o superusuario -- no existe un
--   privilegio INDEX granular como en MySQL. Al hacer que los dos
--   usuarios de consulta sean miembros de este rol, heredan los
--   derechos de dueño (incluida la creación de índices) solo sobre
--   estos objetos, sin ser superusuarios de la instancia.
--
-- brechas_camilo / brechas_david: roles de LOGIN, uno por integrante,
--   miembros de brechas_owner_role.
--
-- CAMBIA ESTAS CONTRASEÑAS antes de ejecutar.
-- =====================================================================
CREATE ROLE brechas_owner_role NOLOGIN;

CREATE ROLE brechas_camilo LOGIN PASSWORD 'CambiaEstaClave2026*';
CREATE ROLE brechas_david  LOGIN PASSWORD 'CambiaEstaClave2026*';

GRANT brechas_owner_role TO brechas_camilo;
GRANT brechas_owner_role TO brechas_david;

-- Necesario para que el usuario postgres pueda "ponerse el sombrero"
-- de brechas_owner_role al crear las tablas en el script 01 (así
-- quedan con ese rol como dueño desde el principio, sin tener que
-- hacer ALTER TABLE ... OWNER TO después de cada CREATE TABLE).
GRANT brechas_owner_role TO postgres;

-- Para poder conectarse a la base, un rol necesita el privilegio
-- CONNECT sobre ella (en MySQL esto es implícito).
GRANT CONNECT ON DATABASE brechas_seguridad TO brechas_camilo, brechas_david;


-- =====================================================================
-- 3. VERIFICACIÓN
-- =====================================================================
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN ('brechas_camilo', 'brechas_david', 'brechas_owner_role')
ORDER BY rolname;

-- Fin del script 00
