# Sección 02 — Net sales y devoluciones que llegan tarde

Qué va a contestar esta sección, con qué reglas y qué deja deliberadamente fuera.
Se escribe **antes** de la prosa del report para que el análisis no derive hacia
lo fácil.

Es un documento de trabajo: cuando la sección esté escrita, se archiva. El
contexto permanente sigue siendo [`decisiones.md`](decisiones.md) y
[`hallazgos_auditoria.md`](hallazgos_auditoria.md).

**Estado:** el texto está en
[`seccion_02_hipotesis_report.md`](seccion_02_hipotesis_report.md) y el HTML
aislado se genera con `make report` en `report/index2.html` (aún no fusionado en
`report/index.html`).

La pregunta del brief, literal: *"In this dataset, `quantity_returned` lives on
the same row as the original sale — and that value is updated in place when the
return happens. […] We'd like you to design how this should be modeled. Propose a
schema. Decide which metric definitions you'd defend ("net sales as-of date of
sale" versus "net sales as-of report date"). Sketch how a chart that looks correct
today should behave six months from now when the returns trickle in."*

---

## 1. Lo que ya está decidido y aquí se aplica o se acota

- **No hay fecha de devolución** en el origen: la fila se sobrescribe
  ([D-08](decisiones.md)). El puente es un snapshot (o una tabla de eventos si se
  puede tocar el origen).
- **D-16 queda acotada.** *As-of date of sale* es lo que la sección 01 (y la 03)
  usan porque el esquema actual no da otra opción. **No** es la definición que la
  compañía debería defender una vez exista el puente. Esta sección la sustituye
  ([D-22](decisiones.md)).
- **Zona `Europe/Madrid`, corte 29–30 de mayo de 2026** ([D-17](decisiones.md)).
- **DQ-08:** las devoluciones tardías del brief no están en los datos (tasa plana
  ~14,8% hasta el último mes). El *cuándo* hay que simularlo y etiquetarlo.
- **D-21** ya cobraba el coste una vez por línea; aquí se eleva a regla de
  negocio del evento: **una sola devolución por order line**, todas las unidades
  de golpe.

---

## 2. Lo que se decide aquí

### Definición defendida: as-of return date (flujo de caja)

El brief plantea *as-of date of sale* vs *as-of report date*. Las dos atribuyen la
devolución al **mes de la venta**. Con un esquema shipeable (snapshot + evento)
capturamos el momento en que `quantity_returned` cambia y atribuimos la
devolución al **mes en que ocurre**. Eso es lo que defendemos: el neto del mes
cuenta lo que entró y lo que salió de caja ese mes.

- *As-of report date* se descarta: se reescribe sola; es la mentira del brief.
- *As-of date of sale* queda como vista secundaria de cohorte ("¿qué tal se
  portó lo vendido en enero?"), no como cifra primaria de cierre.

### Diseño, no implementación en el repo

No se crea `transform/snapshots/` ni modelos nuevos. El esquema se propone: DDL,
bloque `{% snapshot %}` y lógica de `int_return_event`, embebidos en el report.
Los gráficos son **ilustraciones** de esa propuesta; viven en
`report/curva_devoluciones.py` y van etiquetados como asunción, no como
medición.

### Curva declarada: 30–90 días, pico a 45

Ventana del brief. La forma evita el artefacto de llegada uniforme.

### Una devolución = un evento atómico por order line

El cliente o devuelve de una vez todas las unidades que quiera de esa línea, o
nunca más podrá devolver sobre ella. No hay batches `0 → 1 → 2`. Una línea con
`quantity_returned = 3` es un único evento de tres unidades.

### PK del snapshot: solo dimensiones

`(created_at, channel, sku, shipment_id)` es única en las 50.000 líneas. La
`unique_key` del snapshot se construye con esas cuatro. Aun así se pide una PK
real (`sale_order_line_id`) a origen. La clave staging actual mete
`quantity_returned` en el `md5` y no sirve para snapshotear.

### Cadencia diaria

Semanal perdería resolución dentro de la ventana 30–90.

---

## 3. Las preguntas que esta sección se compromete a responder

1. **¿Por qué el esquema actual empieza a mentir el trimestre siguiente?**
2. **¿Qué esquema proponemos** (ideal aguas arriba + puente con snapshot) que se
   pueda shippear hoy?
3. **¿Qué definición defendemos?** As-of return date; por qué no las dos del
   brief.
4. **¿Cómo se comporta un gráfico correcto a seis meses** bajo esa definición?
   (Los meses de venta no se reescriben; el débito aparece cuando aterriza.)
5. **¿Qué regla operativa** aplicaría un equipo el lunes?

---

## 4. Lo que no entra

- Materializar el snapshot o `int_return_event` en dbt.
- Cambiar los marts de la sección 01 (siguen en cohorte de venta; se dice en voz
  alta).
- Coste de devolución y margen (sección 03).
- Simular batches de devolución por línea.
- Fusionar `index2.html` en `index.html` (más adelante).

---

## 5. Dónde vive cada respuesta

| Respuesta | Dónde |
|---|---|
| Problema + DQ-08 + bug de la clave | Prosa del report, bloque A |
| DDL ideal + snapshot + `int_return_event` | Prosa + fences SQL/Jinja, bloque B |
| Definiciones y veredicto | Tabla + prosa, bloque C ([D-22](decisiones.md)) |
| Curva y sketch a 6 meses | `report/curva_devoluciones.py` + charts `curva_madurez`, `mismo_mes`, `caja_mensual` |
| Regla operativa | Prosa, bloque E |

---

## 6. Cómo se sabrá que la sección está bien

- Un lector sabe por qué el esquema actual miente, ve un esquema shipeable, y
  sale defendiendo **as-of return date** (caja), no las dos del brief.
- Ve el sketch a seis meses: venta estable, débito cuando aterriza.
- Cada gráfico dice que es ilustración con curva declarada.
- `report/index.html` no cambia; la 02 vive en `report/index2.html`.
- Ninguna cifra real contradice `hallazgos_auditoria.md` ni los marts de la 01.
