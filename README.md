# ALOHAS · case study de Analytics Engineer

Dos años de ventas en BigQuery, tres preguntas, y un dataset sintético con
problemas plantados dentro. Este repositorio tiene el report, el código que
produce cada número y el rastro de las decisiones que hubo que tomar para que los
números signifiquen algo.

**Estado:** report completo en [`report/report.html`](report/report.html)
(secciones 01, 02 y 03).

## Por dónde empezar

1. **El report**, que es el entregable:
   [`report/report.html`](report/report.html). Es un HTML autocontenido —lleva los
   gráficos dentro y funciona sin conexión—. Se lee entero por sí solo.
2. **Qué encontramos al auditar los datos**:
   [`hallazgos_auditoria.md`](hallazgos_auditoria.md). Once problemas de calidad,
   cada uno con su ejemplo real y la consulta que lo demuestra.
3. **Qué decidimos y por qué**: [`decisiones.md`](decisiones.md). Cuando el dato
   no daba una respuesta, ahí está escrito qué asumimos en su lugar y qué
   consecuencia tiene.

El report cita esos dos documentos por su código (DQ-xx y D-xx): ahí está el
detalle de cada hallazgo y de cada decisión que el informe solo resume.

## Cómo abrir el report

```bash
git clone git@github.com:brianabascal/alohas_case_study_brian.git
cd alohas_case_study_brian
xdg-open report/report.html   # macOS: open · Windows: start
```

No hace falta instalar nada: los gráficos y la hoja de estilo van dentro del
fichero. Hay que abrirlo en el navegador —en la vista de GitHub no se renderiza—.

## Cómo está montado el repo

| Carpeta | Qué hay |
|---|---|
| `report/` | `report.html`, el informe completo (secciones 01, 02 y 03) en un solo fichero. La 01 y la 03 salen de los marts; la 02 es una propuesta de esquema y sus gráficos de madurez son ilustraciones con curva declarada, no una medición. |
| `transform/` | El proyecto dbt. `staging/` limpia y tipa las tres tablas de origen, `intermediate/` concentra las reglas de ingreso y de margen, `marts/` tiene el hecho a grano de línea más un mart por bloque de preguntas, y `seeds/` guarda los parámetros del escenario de canal. |
| `analysis/audit/` | Las consultas exploratorias de la auditoría, cada una con su CSV en `out/`. Son el rastro de cómo se encontró cada problema, no código de producción. |
| `scripts/` | `bq.py` es un runner de solo lectura contra la API REST de BigQuery; `extract.py` lo usa para bajar las tres tablas a `data/raw/`. |
| `data/` | Los CSV de origen versionados y el warehouse local de DuckDB, que se regenera. |

Los documentos vivos de la raíz son la auditoría y las decisiones.

## Cómo reproducirlo

Los CSV de origen están versionados, así que **no hace falta acceso a BigQuery**
para levantar el warehouse y comprobar de dónde sale cada número del report:

```bash
make venv     # entorno virtual e instalación de requirements.txt
make build    # dbt seed + dbt run + dbt test: reconstruye data/alohas.duckdb
```

`make extract` vuelve a bajar las tablas de BigQuery y solo funciona con las
credenciales de aplicación activas y permisos de lectura sobre
`alohas-recruiting-study-case`. El rol es de solo lectura y no hay ni una
credencial en el repositorio.

El warehouse es DuckDB en un fichero local: es lo que permite que cualquiera
levante el proyecto entero sin una cuenta en ningún sitio. Los tests son de dos
tipos: los de esquema, en los `_*.yml` de cada capa, y singulares en
`transform/tests/` que comprueban lo que de verdad puede romperse —que la escalera
de ingresos cuadra con el hecho, que el CM de canal cuadra con las líneas
costadas, que la tarifa de transporte es plana y que las cantidades son
coherentes—.

## Lo que haría con más tiempo

- **Publicar el filo en vez de un escenario.** Hoy la sección 03 corrige el precio
  de mayorista y la comisión de marketplace con dos números elegidos del centro de
  la horquilla del sector. Lo elegante sería calcular a partir de qué comisión o de
  qué precio cada canal deja de ser rentable, para que el lector ponga el suyo.
- **Calendario retail 4-5-4.** Con calendario natural, Black Friday puede caer en
  semanas distintas y la comparativa de noviembre miente.
- **Sensibilidad a la convención de la devolución**: cuánto se mueve el ranking si
  la prenda devuelta sí se revende, o si traerla cuesta el doble.
- **Un test de calidad continuo** que avise si vuelven a aparecer artículos fuera
  de catálogo o envíos sin venta, en vez de haberlo encontrado a mano una vez.
