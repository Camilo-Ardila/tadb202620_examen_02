# tadb202620_examen_02

Repositorio del **Examen No. 2 – Índices y Mejoras en el Desempeño de Consultas** del curso
**Tópicos Avanzados de Bases de Datos** (Universidad Pontificia Bolivariana, periodo 202620).

Dominio del problema: **Análisis de brechas de seguridad**.

## Integrantes

| Estudiante | ID SIGAA | Motor de base de datos |
|---|---|---|
| Camilo José Ardila Restrepo | 000543367 | PostgreSQL 18 |
| David Berrío Martínez | 000547257 | MySQL 8.4 |

Docente: Juan Darío Rodas M.

## Estructura del repositorio

```
tadb202620_examen_02/
├── README.md
├── .gitignore
├── Enunciado/            Enunciado del examen (PDF)
├── Diagrama/             Diagrama relacional compartido (draw.io y PNG con fondo blanco)
├── data/                 Sábana de datos sintéticos en 4 lotes CSV (40,000 filas)
├── MySQL/                Entregables de David Berrío Martínez
│   ├── Abastecimiento/   PDF de abastecimiento y conectividad + docker-compose.yml
│   ├── Scripts/          Scripts SQL (UTF-8)
│   ├── PlanesEjecucion/  Documento Word con los planes de ejecución
│   ├── Resultados/       Registros resultantes de las etapas 3 y 4 (CSV)
│   └── BitacoraIA/       PDF con la interacción con la herramienta de IA
└── PostgreSQL/           Entregables de Camilo José Ardila Restrepo (misma estructura)
```

## Scripts de MySQL (ejecutar en orden)

| Script | Contenido |
|---|---|
| `01_implementacion_modelo_brechas_mysql.sql` | Esquema, usuarios con privilegios mínimos, tablas, restricciones e índices |
| `02_carga_datos_brechas_mysql.sql` | Carga de la sábana CSV y poblamiento del modelo normalizado, con validaciones |
| `03_funciones_procedimientos_vistas_mysql.sql` | Funciones, procedimientos y vistas |
| `04_consultas_brechas_mysql.sql` | Consultas de las etapas 3 y 4 con la comparación de desempeño (índices invisibles / visibles) |

## Infraestructura MySQL

MySQL 8.4 en contenedor Docker (`MySQL/Abastecimiento/docker-compose.yml`), expuesto en el
puerto 3307 del equipo anfitrión, con conectividad desde DBeaver.

```bash
cd MySQL/Abastecimiento
docker compose up -d
```

## Uso de inteligencia artificial

La interacción con la herramienta de IA se documenta, con capturas de pantalla de toda la
conversación, en la carpeta `BitacoraIA` de cada motor.
