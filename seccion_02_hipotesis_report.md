# 02 — Net sales y devoluciones que llegan tarde

> Propuesta de modelado. El esquema no está materializado en dbt: se declara
> aquí porque es lo que el brief pide. Los gráficos son ilustraciones con una
> curva asumida (30–90 días, pico a 45), no una medición — en este dataset las
> devoluciones ya llegaron todas ([DQ-08](hallazgos_auditoria.md)).

La pregunta del brief cabe en tres frases: la fila de venta es mutable, las
devoluciones llegan tarde, y un dashboard construido sobre este esquema
*"empezaría a mentir el trimestre siguiente"*. Piden un esquema, una definición
de métrica que se defienda, y un boceto de cómo se comporta un gráfico correcto
dentro de seis meses. Eso es todo lo que hay aquí.

---

## 1. El problema, con las cifras de este dataset

`quantity_returned` vive en la misma fila que la venta. Cuando el cliente
devuelve, esa celda se actualiza in-place: una línea que hoy lee `0` puede leer
`3` dentro de un mes, sin fila nueva y sin `returned_at`. Son 8.256 líneas con
devolución (9.514 unidades sobre 64.391, el 14,8%), y 973 de ellas devuelven
entre dos y cuatro unidades de un golpe.

El brief avisa de que las devoluciones llegan entre 30 y 90 días después de la
venta. **En estos datos eso no se ve.** La tasa de devolución por mes de venta
es plana en los 25 meses, alrededor del 14,8%. Mayo de 2026 —vendido a tres
semanas del corte— marca 15,2%, por encima de la media. Si el lag fuera real,
ese mes debería estar casi a cero. El generador materializó las devoluciones en
el instante de la venta: tenemos una foto completamente madura, no un corte vivo
([DQ-08](hallazgos_auditoria.md), [D-08](decisiones.md)).

Consecuencia: el sesgo del que avisa el brief es real como riesgo futuro, y
**aquí no se puede medir, hay que simularlo**. La trampa no es un dato malo: es
un dato demasiado limpio.

Hay un segundo problema, casero. La clave surrogada que usa el staging mete
`quantity_returned` dentro del `md5` y del `row_number()`. Si una línea pasa de
0 a 3, su clave cambia: un snapshot vería un borrado y un alta, no una
actualización. El puente que necesitamos ni siquiera arranca con la clave
actual. Eso también se diseña aquí.

---

## 2. El esquema que se puede shippear hoy

El movimiento central es separar el **evento** del **estado**. Una devolución es
un hecho con fecha propia, no un contador pegado a la venta. Sin esa separación
solo quedan las dos lecturas del brief, las dos malas para cerrar el mes de
caja.

### Ideal, si se puede tocar el origen

```sql
-- La línea de venta deja de mutar. PK real, no un hash.
alter table fct_sale_order_line
  add column sale_order_line_id string not null;

-- La devolución es una entidad. Como máximo una por línea de pedido:
-- el cliente o devuelve de una vez todas las unidades que quiera de esa línea,
-- o nunca más podrá devolver sobre ella.
create table fct_return_line (
  return_id           string not null,
  sale_order_line_id  string not null,
  returned_at         timestamp not null,
  quantity_returned   int64 not null,
  primary key (return_id),
  unique (sale_order_line_id)   -- un solo evento por order line
);
```

`quantity_returned` en la sale line se depreca o se convierte en un derivado del
evento. El grano del return es una fila = un evento = todas las unidades
devueltas de esa línea en ese momento. Una línea con tres unidades devueltas no
son tres aterrizajes: es uno.

### Puente, cuando no controlas el origen

Es lo que se puede shippear **mañana** sin esperar a que producción emita
`fct_return_line`. Tres piezas.

**1. Staging con clave estable.** Solo dimensiones, verificada única en las
50.000 líneas de este dataset:

```sql
md5(concat_ws('||',
  cast(created_at as varchar),
  cast(channel as varchar),
  cast(sku as varchar),
  coalesce(cast(shipment_id as varchar), '')
)) as sale_order_line_sk
```

`(created_at, channel, sku, shipment_id)` no colisiona ni una vez. Sin
`created_at` sí hay 63 grupos duplicados. Aun así, lo que se pide a origen es
una columna `sale_order_line_id`: un hash de dimensiones aguanta mientras el
generador no meta dos líneas idénticas el mismo segundo; una PK de verdad
aguanta siempre.

**2. Snapshot diario sobre `quantity_returned`.**

```sql
{% snapshot snp_sale_order_line %}
{{ config(
    target_schema='snapshots',
    unique_key='sale_order_line_sk',
    strategy='check',
    check_cols=['quantity_returned'],
    hard_deletes='invalidate'
) }}

select
    sale_order_line_sk,
    channel,
    sku,
    shipment_id,
    quantity_sold,
    quantity_returned,
    gross_sale,
    taxes,
    net_sales,
    created_at
from {{ ref('stg_fct_sale_order_line') }}

{% endsnapshot %}
```

Cadencia diaria. Semanal perdería resolución dentro de la ventana 30–90 del
brief: una devolución que aterriza el martes y otra el viernes del mismo lag
parecerían el mismo día.

**3. El evento, derivado del diff.**

```sql
-- int_return_event: una fila por order line que alguna vez devolvió.
-- Cuando quantity_returned pasa de 0 a N, emitimos UN evento.
-- returned_at ≈ dbt_valid_from de la versión nueva.

select
    sale_order_line_sk,
    quantity_returned          as quantity,
    dbt_valid_from             as returned_at,
    date_trunc('month',
      cast((dbt_valid_from at time zone 'UTC')
           at time zone 'Europe/Madrid' as date)
    )                          as return_month
from {{ ref('snp_sale_order_line') }}
where quantity_returned > 0
  and dbt_valid_to is null     -- versión actual
  -- y existía una versión previa con quantity_returned = 0
;
```

Si el dato mostrara un segundo incremento (`1 → 2`), no se modela como segundo
evento: por regla de negocio no existe ([D-22](decisiones.md)). Es una alerta de
calidad. Lo que sí rompe el modelo —y hay que decirlo—: borrados duros de la
fila de venta, `quantity_returned` que baja, y un backfill que reescribe
historia sin haber estado snapshoteando antes.

Con esto, si mañana el generador actualiza `quantity_returned` de una order
line, el snapshot lo captura y el evento se carga al **mes de la devolución**.
Ese es el único motivo de negocio de todo el puente.

---

## 3. Qué definición se defiende

El brief pide elegir entre *as-of date of sale* y *as-of report date*. Las dos
atribuyen la devolución al **mes de la venta**. Lo que cambia es con qué
información se calcula. Ninguna de las dos cierra el mes de caja.

| Definición | ¿Dónde cae la devolución? | Qué pregunta contesta | Veredicto |
|---|---|---|---|
| As-of report date | Mes de la venta, con todo lo conocido hoy | Ninguna fiable | **Descartada** — se reescribe sola; es la mentira del brief |
| As-of date of sale | Mes de la venta, congelado al cierre | Cohorte: ¿qué tal lo vendido en enero? | Vista secundaria posible *con* snapshot; **no** es la primaria. La sección 01 la usa porque hoy no hay `returned_at` ([D-16](decisiones.md)) |
| As-of return date | Mes en que aterriza el evento | Caja: ¿qué entró y salió en enero? | **Defendida** — shipeable con el esquema de arriba ([D-22](decisiones.md)) |

**Defendemos solo as-of return date.** El ingreso neto del mes es:

```text
ventas del mes (sin IVA) − devoluciones cuyo returned_at cae en el mes
```

Si mañana sube `quantity_returned`, lo capturamos y lo cargamos a ese mes
contable. Enero de ventas no se reescribe. Eso es lo que un CFO espera de una
serie mensual de caja.

Las otras dos se explican para contestar el brief, no como alternativas en pie
de igualdad. *As-of report date* es el default del esquema mutable y es
exactamente el aviso del brief. *As-of date of sale* mide la cohorte comercial
—útil el martes siguiente para preguntar “qué tal se portó lo que vendimos en
enero”— pero no cierra el mes contable. La sección 01 la usa porque el esquema
actual no da otra cosa; aquí proponemos dejar de vivir así.

---

## 4. Cómo se comporta un gráfico correcto dentro de seis meses

La curva de llegada es una asunción: entre 30 y 90 días, con pico alrededor de
los 45. Es la ventana que da el brief; la forma evita el artefacto de que todo
llegue al mismo ritmo. En este dataset el *cuándo* no se puede medir, así que
cada figura lo dice en el título.

[[chart:curva_madurez]]

El sketch que pide el brief —*cómo se comporta un gráfico que hoy parece
correcto cuando las devoluciones van aterrizando*— cambia de forma bajo la
definición defendida. Bajo as-of report date, el neto de enero de ventas **cae**
a medida que llegan devoluciones: el mes se reescribe solo. Bajo as-of return
date, ese mismo mes de ventas **se queda quieto**; el débito aparece en los
meses en que aterriza la devolución.

[[chart:mismo_mes]]

La serie que un liderazgo debería mirar el lunes es la de caja: ventas del mes
menos devoluciones con `returned_at` en el mes. **Aquí no hay una segunda línea
"madura" ni una cola pendiente que corregir.** Una devolución que todavía no ha
ocurrido no pertenece a este mes: aparecerá una sola vez, en el mes futuro en
que aterrice. Al contrario que *as-of report date* y *as-of date of sale*, los
meses de caja ya cerrados no se reescriben.

[[chart:caja_mensual]]

La línea única no es falta de información: es la propiedad que defendemos. A
seis meses, los meses anteriores conservan exactamente el mismo valor y los
nuevos débitos aparecen cuando ocurren. Correcto, no un bug.

---

## 5. La regla operativa

Tres líneas, accionables el lunes:

1. **Publicar el neto del mes como cifra de caja**, con as-of return date. No
   publicar as-of report date en ningún dashboard de liderazgo.
2. **Un mes de caja se cierra en calendario.** Las devoluciones de ventas
   recientes seguirán entrando en meses futuros, y eso es correcto.
3. **La vista de cohorte** (as-of date of sale) puede vivir al lado, para
   preguntar cómo se portó lo vendido en un mes, y un mes de ventas se
   considera completo en devoluciones a los 90 días. No sustituye a la de caja.

El plan de la sección y las decisiones permanentes están en
[`seccion_02_hipotesis.md`](seccion_02_hipotesis.md) y
[`decisiones.md`](decisiones.md).
