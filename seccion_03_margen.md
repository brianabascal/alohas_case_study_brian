# Sección 03 — Contribution margin

Qué va a contestar esta sección, con qué reglas y qué deja deliberadamente fuera.
Se escribe **antes** de la prosa del report para que el análisis no derive hacia
lo fácil.

Es un documento de trabajo: cuando la sección esté escrita, se archiva. El
contexto permanente sigue siendo [`decisiones.md`](decisiones.md) y
[`hallazgos_auditoria.md`](hallazgos_auditoria.md).

**Estado:** el texto está en
[`seccion_03_margen_report.md`](seccion_03_margen_report.md). `make report`
genera [`report/report.html`](report/report.html) (secciones 01, 02 y 03).

La pregunta del brief, literal: *"Each unit sold has costs attached to it. The
cost of the product itself (`dim_product.cost`). The cost of getting it to the
customer (`fct_shipment.shipping_cost`). And, when applicable, the cost of a
return. Build a view of contribution margin. By channel, by category, by
something else if you find something worth showing. Tell us which products and
which channels are actually making money — and which ones look healthy on a
revenue chart but stop looking healthy here. Be specific about how you handle
returns and shipping allocation; the assumptions matter as much as the answer."*

---

## 1. Lo que ya está decidido y aquí solo se aplica

- **El titular del ingreso sigue siendo el neto** (sin IVA y descontando lo
  devuelto) ([D-15](decisiones.md)). La escalera se alarga hasta el margen de
  contribución: ingreso neto − coste de producto − transporte − coste de
  devolución.
- **Lectura a fecha de la venta** ([D-16](decisiones.md)): con el esquema actual
  no hay otra opción. La sección 02 defiende as-of return date para el futuro;
  esta sección no reabre eso.
- **Zona `Europe/Madrid`, corte del dataset** ([D-17](decisiones.md)).
- **Transporte = factura repartida**, no coste de la venta
  ([D-06](decisiones.md)): pool de envíos referenciados ÷ 50.000 líneas; columna
  `shipping_cost_allocated`; huérfanos fuera; nunca `sum(fct_shipment)`.
- **Sin ficha de producto no hay margen** ([D-09](decisiones.md)): ~1,6% del
  ingreso neto queda fuera y se publica.
- **Todo margen es un techo** ([D-12](decisiones.md)): sin descuentos, wholesale
  a PVP, coste de catálogo de hoy sobre ventas de hace dos años.
- **Comisiones de pago y pick&pack fuera** ([D-14](decisiones.md)).
- **Escenario realista en capa aparte** ([D-18](decisiones.md)): wholesale al
  45% del PVP y marketplace al 17,5% de comisión; viven en la seed
  `channel_economics` y producen medidas nuevas, no pisan el dato original.
- **La prenda devuelta no se revende** ([D-19](decisiones.md)): el COGS se carga
  sobre `quantity_sold`.
- **Devolver cuesta lo mismo que enviar**, una vez por línea con devolución
  ([D-21](decisiones.md)).
- **El canal es casi una etiqueta** ([D-20](decisiones.md)): el ranking de margen
  con datos originales se publica con el mismo aviso que el de ingreso.

---

## 2. Lo que se decide aquí

### El ranking titular mira los dos años enteros

El brief pregunta *quién gana dinero*, no *quién creció en margen*. El periodo
es el dataset completo. No hay serie mensual de CM como KPI: el surtido y las
convenciones de coste no cambian con el tiempo de forma medible (precio y coste
de catálogo fijos), así que una serie temporal añadiría ruido sin tesis.

### La base del margen no es la base del ingreso de la 01

Solo entran líneas con `is_catalog_product`. El gap (~1,6% del ingreso neto) se
declara en el report al lado de la primera cifra, para que nadie reste la 01
contra la 03 y crea que se ha perdido dinero.

### Tres cortes: canal, categoría y producto

- **Canal**: ranking en € y en %, stack de costes y las dos lecturas que se
  publican (datos originales → IVA igualado), más el escenario realista D-18.
- **Categoría**: ranking de CM% y el mix de costes que lo explica (COGS,
  transporte plano, devolución).
- **Producto (SKU)**: el *something else* del brief. Top/bottom por CM y el
  contraste con quién lidera en ingreso neto: lo que parece sano en un chart de
  revenue y deja de parecerlo aquí.

### Dos lecturas del margen por canal, más el escenario

1. **Datos originales**: lo que dice el dato con las convenciones D-06/D-19/D-21.
2. **IVA igualado**: los cuatro canales al 21%, para ver cuánta ventaja de
   wholesale es fiscal.
3. **Escenario realista D-18**: wholesale ×0,45 y fee de marketplace 17,5%.

Las dos primeras diagnostican el ranking del dato original; la tercera es la
lectura de negocio, etiquetada como capa de escenario.

El audit #29 calculó una cuarta lectura —“sin efecto de devolución”: la prenda
se revende y no cuesta traerla— y **no se publica**. Con D-19 decidido (la
prenda no vuelve a stock), enseñar que sin devoluciones los cuatro canales
empatan no aporta nada que la sección 01 no dijera ya, y confunde el diagnóstico
del margen. La columna `cm_no_return_effect_pct` sigue en el mart como salida de
auditoría; simplemente no se dibuja.

### HTML del report

`make report` genera un solo fichero, [`report/report.html`](report/report.html):
dos bloques HTML autocontenidos concatenados (01+02, luego 03), cada uno con su
propia cabecera y pie.

---

## 3. Las preguntas que esta sección se compromete a responder

### Definición

1. **¿Cómo se construye el margen de contribución, y qué asume sobre transporte
   y devoluciones?** La fórmula, las tres convenciones de D-21, el pool de D-06 y
   el aviso de que es un techo (D-12).

### Canal

2. **¿Qué canal gana más euros de contribución y cuál tiene mejor margen
   porcentual con los datos originales?** Casi nunca son el mismo ranking.
3. **¿Cuánto de ese ranking es impuesto?** La lectura con IVA igualado al 21%.
4. **¿Qué pasa al aplicar el escenario ficticio realista** (wholesale al 45% del
   PVP, marketplace al 17,5%)? Quién deja de ser rentable y quién es el motor
   del negocio en euros.

### Categoría

5. **¿Qué categorías dejan más margen y por qué?** Ranking de CM% y el mix de
   costes detrás: transporte plano que castiga lo barato, COGS que no es plano
   (Bags vs Shoes), y euros por línea frente a porcentaje.

### Producto

6. **¿Qué SKUs hacen dinero de verdad y cuáles lideran en ingreso pero se caen
   en CM?** El contraste revenue-sano / CM-roto que pide el brief.

### Puente con la 01

7. **¿Por qué el ingreso de la 01 y la base de la 03 no cuadran?** El 1,6% sin
   ficha (D-09), escrito al lado del número. Y qué canales o productos que
   parecían sanos en un chart de revenue dejan de parecerlo cuando se abre el
   coste.

---

## 4. Lo que no entra

- **Cualquier corte por país** o por método de envío: el vínculo venta↔envío es
  ruido ([D-06](decisiones.md)).
- **Umbral/filo de rentabilidad** (a partir de qué comisión o precio de mayorista
  cada canal deja de ser rentable): queda en “más tiempo” del README.
- **Sensibilidad** a “la prenda sí se revende” o a devolver al doble: las
  convenciones D-19 y D-21 se declaran, pero no se publica ni la lectura “sin
  efecto de devolución” ni un panel de sensibilidad.
- **Comisiones de pago y pick&pack** ([D-14](decisiones.md)).
- **Serie mensual de CM** como KPI.
- **Un solo documento HTML recompuesto** (la unión es concatenación de bloques, no
  una plantilla única).

---

## 5. Dónde vive cada respuesta

| Modelo | Preguntas | Qué contesta |
|---|---|---|
| `channel_economics` (seed) | 1, 4 | Parámetros visibles del escenario y del multiplicador de devolución. |
| `int_sale_line_margin` | todas | Línea costada: COGS, `shipping_cost_allocated`, coste de devolución, CM del dato original y medidas de escenario. |
| `rpt_channel_contribution` | 2, 3, 4, 7 | Stack por canal + TODOS; CM con datos originales / IVA igualado / escenario realista (y la lectura sin devolución, que no se publica). |
| `rpt_category_contribution` | 5 | Ingreso, CM%, mix de costes (COGS / transporte / devolución) por categoría. |
| `rpt_product_contribution` | 6, 7 | SKU: ingreso, CM, ranks; contraste revenue vs margen. |

Los modelos de la sección 01 (`fct_sale_line`, `rpt_channel_*`) no se mutan: son
el contrato de ingreso. El gap D-09 se lee cruzando la escalera de la 01 con la
base del mart de margen.

---

## 6. Cómo se sabrá que la sección está bien

- Un lector sabe **cómo** se imputan transporte y devoluciones, ve qué canal y
  qué productos hacen dinero con los datos originales, y entiende por qué el
  escenario realista D-18 le da la vuelta a wholesale.
- Todos los números del report salen de los marts y de la seed; `build_report.py`
  solo dibuja.
- `report/report.html` contiene las tres secciones; los números salen de los
  marts y de la seed.
- Los tests de dbt pasan, incluido que el CM de `TODOS` cuadra con la suma de
  líneas costadas y que `shipping_cost_allocated` es constante.
- Ninguna cifra contradice `hallazgos_auditoria.md` ni el audit #29 (salvo
  redondeo documentado).
