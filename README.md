# ALOHAS · case study de Analytics Engineer

Dos años de ventas en BigQuery, tres preguntas, y un dataset sintético con
problemas plantados dentro. Este repositorio tiene el report, el código que
produce cada número y el rastro de las decisiones que hubo que tomar para que los
números signifiquen algo.

**Estado:** report completo en [`report/report.html`](report/report.html)
(secciones 01, 02 y 03).

## Por dónde empezar

1. **El report**, que es el entregable: [`report/report.html`](report/report.html)
   (HTML autocontenido —lleva los gráficos dentro y funciona sin conexión—).
   El texto de la 03 está en
   [`seccion_03_margen_report.md`](seccion_03_margen_report.md); el de las
   primeras dos, en `archivo/`.
2. **Qué encontramos al auditar los datos**:
   [`hallazgos_auditoria.md`](hallazgos_auditoria.md). Once problemas de calidad,
   cada uno con su ejemplo real y la consulta que lo demuestra.
3. **Qué decidimos y por qué**: [`decisiones.md`](decisiones.md). Cuando el dato
   no daba una respuesta, ahí está escrito qué asumimos en su lugar y qué
   consecuencia tiene.

## Cómo está montado el repo

| Carpeta | Qué hay |
|---|---|
| `report/` | `build_report.py` monta `report.html` (secciones 01, 02 y 03). La 01 y la 03 leen marts; la 02 es una propuesta de esquema con ilustraciones (`curva_devoluciones.py`). |
| `transform/` | El proyecto dbt. `staging/` limpia y tipa las tres tablas de origen, `intermediate/` concentra las reglas de ingreso y de margen, `marts/` tiene el hecho a grano de línea más un mart por bloque de preguntas, y `seeds/` guarda los parámetros del escenario de canal. |
| `analysis/audit/` | Las consultas exploratorias de la auditoría, cada una con su CSV en `out/`. Son el rastro de cómo se encontró cada problema, no código de producción. |
| `scripts/` | `bq.py` es un runner de solo lectura contra la API REST de BigQuery; `extract.py` lo usa para bajar las tres tablas a `data/raw/`. |
| `data/` | Los CSV de origen versionados y el warehouse local de DuckDB, que se regenera. |
| `archivo/` | Material de preparación ya superado y planes/prosa de secciones cerradas. |

Los documentos vivos de la raíz son la auditoría, las decisiones y el plan/prosa
de la sección en curso (`seccion_03_margen.md`, `seccion_03_margen_report.md`).

## Cómo reproducirlo

Los CSV de origen están versionados, así que **no hace falta acceso a BigQuery**
para reconstruir el report entero:

```bash
make venv     # entorno virtual e instalación de requirements.txt
make build    # dbt seed + dbt run + dbt test: reconstruye data/alohas.duckdb
make report   # regenera report/report.html
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

## Los supuestos que hay que conocer para leer los números

Están todos razonados en [`decisiones.md`](decisiones.md); estos son los que
cambian lo que se ve en el report.

- **El titular es el ingreso neto**: importe cobrado menos impuestos menos el valor
  de lo devuelto. El campo `net_sales` del dataset **no** es neto de devoluciones,
  solo neto de impuesto, y usarlo para comparar canales pone a wholesale —que
  factura sin impuesto— a competir con tres canales que lo llevan dentro.
- **La devolución se atribuye al mes de la venta**, no al mes en que se devolvió.
- **Grano mensual contra el mismo mes del año anterior**, fechas convertidas a
  `Europe/Madrid` antes de agrupar, y crecimiento medido sobre dos ventanas de 365
  días en vez de años naturales, para que los dos periodos midan lo mismo.
- **El impuesto se quita a nivel global, nunca por país.** El dataset aplica un 21%
  clavado en los ocho países, incluidos Estados Unidos y México.
- **El transporte no se puede atribuir a la venta, solo repartir**: es una factura
  común de 4,13 € por línea. El vínculo entre cada venta y su envío está puesto al
  azar, y por eso tampoco hay ningún corte por país.
- **La devolución cuesta lo mismo que el envío**, se carga una vez por línea con
  devolución y la prenda devuelta no se revende.
- **Todo margen que salga de aquí es un techo.** No hay ni un descuento en dos años
  con dos Black Friday dentro, y el mayorista compra al mismo precio que la web.
- **Las ventas de artículos que no están en el catálogo cuentan como ingreso pero
  no entran en el margen**, porque no tienen coste. Son el 1,6%, y por eso las
  cifras de la sección 01 y las de la 03 no cuadrarán entre sí.

Y un aviso que es en sí mismo un hallazgo: **el canal, en este dataset, es casi una
etiqueta**. Los cuatro venden los mismos artículos, en la misma proporción, al
mismo precio y con el mismo coste. Lo único que los separa de verdad es quién paga
impuesto y quién devuelve, y el report se publica diciéndolo.

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
