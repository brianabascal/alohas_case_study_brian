# ALOHAS · case study de Analytics Engineer

Dos años de ventas en BigQuery, tres preguntas, y un dataset sintético con
problemas plantados dentro. Este repositorio tiene el report, el código que
produce cada número y el rastro de las decisiones que hubo que tomar para que los
números signifiquen algo.

**Estado:** publicada la sección 01 (ventas por canal). La sección 02
(devoluciones que llegan tarde) está en borrador aislado en
[`report/index2.html`](report/index2.html). La 03 (margen de contribución) está
en curso.

## Por dónde empezar

1. **El report**, que es el entregable: [`report/index.html`](report/index.html)
   (sección 01) y [`report/index2.html`](report/index2.html) (sección 02, aún no
   fusionada). Son HTML autocontenidos —llevan los gráficos dentro y funcionan
   sin conexión—. El mismo texto está en
   [`seccion_01_canales_report.md`](seccion_01_canales_report.md) y
   [`seccion_02_hipotesis_report.md`](seccion_02_hipotesis_report.md).
2. **Qué encontramos al auditar los datos**:
   [`hallazgos_auditoria.md`](hallazgos_auditoria.md). Once problemas de calidad,
   cada uno con su ejemplo real y la consulta que lo demuestra.
3. **Qué decidimos y por qué**: [`decisiones.md`](decisiones.md). Cuando el dato
   no daba una respuesta, ahí está escrito qué asumimos en su lugar y qué
   consecuencia tiene.

## Cómo está montado el repo

| Carpeta | Qué hay |
|---|---|
| `report/` | `build_report.py` monta `index.html` e `index2.html` a partir de los `.md`. La sección 01 lee marts; la 02 es una propuesta de esquema, y sus gráficos de madurez son ilustraciones (`curva_devoluciones.py`), no una medición. |
| `transform/` | El proyecto dbt. `staging/` limpia y tipa las tres tablas de origen, `intermediate/` concentra las dos reglas que gobiernan todo (conversión horaria con la escalera de ingresos, y los límites del dataset con sus dos ventanas anuales) y `marts/` tiene el hecho a grano de línea más un mart por bloque de preguntas. |
| `analysis/audit/` | Las consultas exploratorias de la auditoría, cada una con su CSV en `out/`. Son el rastro de cómo se encontró cada problema, no código de producción. |
| `scripts/` | `bq.py` es un runner de solo lectura contra la API REST de BigQuery; `extract.py` lo usa para bajar las tres tablas a `data/raw/`. |
| `data/` | Los CSV de origen versionados y el warehouse local de DuckDB, que se regenera. |
| `archivo/` | Material de preparación ya superado. Se guarda porque enseña el camino. |

Los documentos de la raíz son el contexto vivo: la auditoría, las decisiones y
[`seccion_01_canales.md`](seccion_01_canales.md) y
[`seccion_02_hipotesis.md`](seccion_02_hipotesis.md), planes de sección escritos
**antes** de la prosa para que el análisis no derivara hacia lo fácil.

## Cómo reproducirlo

Los CSV de origen están versionados, así que **no hace falta acceso a BigQuery**
para reconstruir el report entero:

```bash
make venv     # entorno virtual e instalación de requirements.txt
make build    # dbt run + dbt test: reconstruye data/alohas.duckdb
make report   # regenera report/index.html e index2.html
```

`make extract` vuelve a bajar las tablas de BigQuery y solo funciona con las
credenciales de aplicación activas y permisos de lectura sobre
`alohas-recruiting-study-case`. El rol es de solo lectura y no hay ni una
credencial en el repositorio.

El warehouse es DuckDB en un fichero local: es lo que permite que cualquiera
levante el proyecto entero sin una cuenta en ningún sitio. Los tests son de dos
tipos: los de esquema, en los `_*.yml` de cada capa, y cuatro singulares en
`transform/tests/` que comprueban lo que de verdad puede romperse —que la escalera
de ingresos cuadra con el hecho, que el mart mensual mantiene su grano y que las
cantidades vendidas y devueltas son coherentes—.

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
