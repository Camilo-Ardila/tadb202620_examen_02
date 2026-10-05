# tadb202620_examen_02

Repositorio del **Examen No. 2 – Índices y Mejoras en el Desempeño de Consultas** del curso
**Tópicos Avanzados de Bases de Datos** (Universidad Pontificia Bolivariana, periodo 202620).

Dominio del problema: **Análisis de brechas de seguridad**.

## Integrantes

| Estudiante | ID SIGAA | Motor de base de datos |
|---|---|---|
| Camilo José Ardila Restrepo | 000543367 | PostgreSQL 18.3 (Amazon RDS) |
| David Berrío Martínez | 000547257 | MySQL 8.4 (Docker) |

Docente: Juan Darío Rodas M.

## Estructura del repositorio

```
tadb202620_examen_02/
│   .gitignore
│   README.md
│
├───data
│       sabana.duckdb                                   (local, no versionado -- ver .gitignore)
│       sabana_brechas_seguridad_lote_1.csv
│       sabana_brechas_seguridad_lote_2.csv
│       sabana_brechas_seguridad_lote_3.csv
│       sabana_brechas_seguridad_lote_4.csv
│
├───Diagrama
│       modelo_brechas_seguridad.drawio
│       modelo_brechas_seguridad.drawio_finalizado.png
│
├───Enunciado
│       tadb_202620_examen02_performance_tuning_20260921.pdf
│
├───MySQL_David_Berrio_000547257
│   ├───Abastecimiento_David_Berrio_000547257
│   │       Abastecimiento_David_Berrio_000547257.pdf
│   │       docker-compose_David_Berrio_000547257.yml
│   │
│   ├───Bitacora_IA_David_Berrio_000547257
│   │       Bitacora_IA_David_Berrio_000547257.pdf
│   │
│   ├───Planes_Ejecucion_David_Berrio_000547257
│   │       Planes_Ejecucion_David_Berrio_000547257.pdf
│   │
│   ├───Resultados_Consultas_David_Berrio_000547257
│   │       Resultado_Etapa3_Brechas_Criticas_David_Berrio_000547257.csv
│   │       Resultado_Etapa4_Historial_US-002823_David_Berrio_000547257.csv
│   │
│   └───Scripts_David_Berrio_000547257
│           01_implementacion_modelo_brechas_mysql_David_Berrio_000547257.sql
│           02_carga_datos_brechas_mysql_David_Berrio_000547257.sql
│           03_funciones_procedimientos_vistas_mysql_David_Berrio_000547257.sql
│           04_consultas_brechas_mysql_David_Berrio_000547257.sql
│
└───PostgreSQL_Camilo_Ardila_000543367
    ├───Abastecimiento_Camilo_Ardila_000543367
    │       Abastecimiento_Camilo_Ardila_000543367.pdf
    │
    ├───Bitacora_IA_Camilo_Ardila_000543367
    │       Bitacora_IA_Camilo_Ardila_000543367.pdf
    │
    ├───Planes_Ejecucion_Camilo_Ardila_000543367
    │       Planes_Ejecucion_Camilo_Ardila_000543367.docx
    │
    ├───Resultados_Consultas_Camilo_Ardila_000543367
    │       Resultado_Etapa3_Brechas_Criticas_Camilo_Ardila_000543367.csv
    │       Resultado_Etapa4_Historial_US-002823_Camilo_Ardila_000543367.csv
    │
    └───Scripts_Camilo_Ardila_000543367
            00_setup_database_and_roles_Camilo_Ardila_000543367.sql
            01_create_schema_postgresql_Camilo_Ardila_000543367.sql
            02_load_data_postgresql_Camilo_Ardila_000543367.sql
            03_funciones_vistas_postgresql_Camilo_Ardila_000543367.sql
            04_consultas_brechas_postgresql_Camilo_Ardila_000543367.sql
            global-bundle.pem
```

## Scripts de MySQL (ejecutar en orden)

| Script | Contenido |
|---|---|
| `01_implementacion_modelo_brechas_mysql_David_Berrio_000547257.sql` | Esquema, usuarios con privilegios mínimos, tablas, restricciones e índices |
| `02_carga_datos_brechas_mysql_David_Berrio_000547257.sql` | Carga de la sábana CSV y poblamiento del modelo normalizado, con validaciones |
| `03_funciones_procedimientos_vistas_mysql_David_Berrio_000547257.sql` | Funciones, procedimientos y vistas |
| `04_consultas_brechas_mysql_David_Berrio_000547257.sql` | Consultas de las etapas 3 y 4 con la comparación de desempeño (índices invisibles / visibles) |

## Scripts de PostgreSQL (ejecutar en orden)

| Script | Contenido |
|---|---|
| `00_setup_database_and_roles_Camilo_Ardila_000543367.sql` | Creación de la base de datos y los roles (ejecutar conectado a `postgres`) |
| `01_create_schema_postgresql_Camilo_Ardila_000543367.sql` | Tablas, restricciones e índices, con las tablas en propiedad del rol de esquema |
| `02_load_data_postgresql_Camilo_Ardila_000543367.sql` | Carga de la sábana CSV (tabla temporal) y poblamiento del modelo normalizado, con validaciones |
| `03_funciones_vistas_postgresql_Camilo_Ardila_000543367.sql` | Funciones y vistas (los "procedimientos" de MySQL se implementan como funciones que devuelven tabla) |
| `04_consultas_brechas_postgresql_Camilo_Ardila_000543367.sql` | Consultas de las etapas 3 y 4 con la comparación de desempeño (creación / eliminación de índices, ya que PostgreSQL no soporta índices invisibles) |

## Infraestructura MySQL

MySQL 8.4 en contenedor Docker (`MySQL_David_Berrio_000547257/Abastecimiento_David_Berrio_000547257/docker-compose_David_Berrio_000547257.yml`), expuesto en
el puerto 3307 del equipo anfitrión, con conectividad desde DBeaver.

```bash
cd MySQL_David_Berrio_000547257/Abastecimiento_David_Berrio_000547257
docker compose -f docker-compose_David_Berrio_000547257.yml up -d
```

## Infraestructura PostgreSQL

PostgreSQL 18.3 en Amazon Aurora/RDS, con conexión cifrada obligatoria
(`rds.force_ssl` activo a nivel de parameter group) y conectividad desde
DBeaver y `psql`. El certificado de CA (`global-bundle.pem`, incluido en
`Scripts_Camilo_Ardila_000543367/`) es público y no sensible; las
credenciales de los roles **no** están versionadas.

```bash
cd PostgreSQL_Camilo_Ardila_000543367/Scripts_Camilo_Ardila_000543367
psql "host=<endpoint> port=5432 dbname=postgres user=postgres sslmode=verify-full sslrootcert=./global-bundle.pem" -f 00_setup_database_and_roles_Camilo_Ardila_000543367.sql
```

## Uso de inteligencia artificial

La interacción con la herramienta de IA se documenta, con capturas de pantalla de toda la
conversación, en la carpeta de bitácora de IA de cada motor.
