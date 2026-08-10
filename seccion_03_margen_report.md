# 03 — Contribution margin

> *Tell us which products and which channels are actually making money — and which
> ones look healthy on a revenue chart but stop looking healthy here.* — pregunta 3
> del brief

En la sección 01, wholesale lideraba el ingreso neto y online parecía el canal
que más se dejaba euros en las devoluciones. Aquí se abre el coste. **Con los
datos originales de Alohas wholesale sigue primero en margen porcentual (53,7%),
pero online es quien pone de verdad la caja: 1,55 millones de contribución
contra 0,96 de wholesale.** Y cuando se aplica un escenario ficticio realista
—mayorista al 45% del PVP y marketplace al 17,5% de comisión— wholesale pasa a
**destruir valor (−2,8%)** y online se queda como motor del negocio.

Dos avisos antes de cualquier ranking. El primero: este margen es un **techo**.
No hay descuentos en dos años, el mayorista compra a precio de escaparate y el
coste del catálogo es el de hoy aplicado a ventas de hace dos años
([D-12](decisiones.md)). El segundo: la base de esta sección **no es** el ingreso
neto de la 01. Salen las 750 líneas sin ficha de producto ([D-09](decisiones.md)):
143.169 €, el 1,6%. Si se restan las dos cifras, esa es la diferencia, no un
agujero.

---

## 1. Qué llamamos margen de contribución

La escalera de la 01 se alarga tres peldaños. El titular sigue siendo el ingreso
neto (sin IVA y descontando lo devuelto). Debajo entran tres costes, y dos de
ellos son convenciones, no campos del dataset:

```
ingreso neto
  − coste de producto          cost × quantity_sold
  − transporte imputado        4,13 € por línea
  − coste de devolución        4,13 € por línea con devolución
                             = margen de contribución
```

**Transporte ([D-06](decisiones.md)).** El vínculo venta↔envío está puesto al
azar, así que no se hereda el `shipping_cost` de la línea. Se reparte el pool de
envíos que alguna venta referencia entre las 50.000 líneas: **4,13 € por línea**.
La columna se llama `shipping_cost_allocated` a propósito. Los 5.758 envíos
huérfanos quedan fuera del pool.

**Devolución ([D-19](decisiones.md) + [D-21](decisiones.md)).** Tres convenciones,
porque el dato no trae entidad de devolución: (1) traer la prenda cuesta lo mismo
que enviarla; (2) se cobra **una vez por línea**, no por unidad; (3) la prenda
**no se revende**, así que el COGS se queda puesto sobre `quantity_sold`. En dos
años eso son 33.622 € de logística inversa sobre las líneas con ficha —el 0,38%
del ingreso de esta base—. Es el suelo del coste de devolver, no una estimación
de almacén ni de atención al cliente.

**Fuera de alcance ([D-14](decisiones.md)):** comisiones de pago y pick&pack. No
están, no se inventan.

Sobre las 49.250 líneas con ficha, el negocio deja **3.254.033 € de contribución
(36,8% del ingreso neto de esta base)**.

[[chart:cm_stack]]

| Canal | Ingreso neto | − COGS | − Transporte | − Devolución | = Contribución | CM % |
|---|---:|---:|---:|---:|---:|---:|
| wholesale | 1.780.060 € | −791.980 € | −30.071 € | −1.433 € | **956.577 €** | **53,7%** |
| retail | 1.703.817 € | −1.062.522 € | −40.552 € | −6.083 € | 594.659 € | 34,9% |
| marketplace | 435.954 € | −273.579 € | −10.403 € | −1.669 € | 150.303 € | 34,5% |
| online | 4.912.734 € | −3.213.426 € | −122.376 € | −24.437 € | 1.552.494 € | 31,6% |
| **TODOS** | **8.832.564 €** | **−5.341.506 €** | **−203.403 €** | **−33.622 €** | **3.254.033 €** | **36,8%** |

---

## 2. Quién gana con los datos originales

El ranking en porcentaje y el ranking en euros **no coinciden**. Wholesale gana
el primero; online gana el segundo, y de lejos.

[[chart:cm_canales]]

| Canal | CM con datos originales | Contribución | Lectura |
|---|---:|---:|---|
| wholesale | 53,7% | 956.577 € | Mejor %; segundo en euros |
| retail | 34,9% | 594.659 € | |
| marketplace | 34,5% | 150.303 € | |
| online | 31,6% | **1.552.494 €** | Peor %; **primero en euros** |

Eso encaja con lo que ya decía la 01: **el canal es casi una etiqueta**
([D-20](decisiones.md)). Los cuatro venden el mismo surtido, al mismo precio y
con el mismo coste. Lo que separa el margen de los datos originales no es lo que
vende cada canal: es quién paga impuesto.

---

## 3. Por qué el ranking engaña: la mitad de la ventaja es fiscal

Wholesale no vende mejor ni compra más barato. Vende sin repercutir IVA, y esos
puntos entran enteros en el margen. La segunda lectura pone los cuatro canales
al 21% sobre el mismo escaparate, con el mismo stack de costes, y deja ver
cuánta ventaja era comercial y cuánta era el impuesto:

[[chart:cm_diagnostico]]

| Lectura | wholesale | retail | marketplace | online | Diferencia |
|---|---:|---:|---:|---:|---:|
| Datos originales | 53,7% | 34,9% | 34,5% | 31,6% | **22,1 pp** |
| IVA igualado al 21% | 41,4% | 34,9% | 34,5% | 31,6% | **9,8 pp** |

Igualar el impuesto le quita a wholesale **12,3 puntos** y estrecha la distancia
entre el mejor y el peor canal de 22,1 a 9,8 puntos: **más de la mitad de la
ventaja del canal más rentable del dataset es fiscal**, no comercial. Lo que
sobra después son las devoluciones —online y marketplace devuelven más, y la
prenda devuelta no vuelve a stock ([D-19](decisiones.md)), así que su coste de
producto se queda puesto—.

---

## 4. Escenario ficticio realista para Alohas

Los datos originales cuadran con lo que trae el dataset, pero cobran el mismo
precio a un mayorista que a un cliente final y no descuentan comisión de
marketplace. La capa de escenario corrige esas dos cosas con parámetros que
viven en la seed `channel_economics` y **no pisan** ninguna columna del dato
original ([D-18](decisiones.md)):

- Wholesale factura al **45% del PVP**.
- Marketplace paga un **17,5%** de comisión sobre lo cobrado al cliente final.

| Canal | CM con datos originales | CM con escenario realista | Contribución con escenario realista |
|---|---:|---:|---:|
| wholesale | 53,7% | **−2,8%** | **−22.456 €** |
| retail | 34,9% | 34,9% | 594.659 € |
| online | 31,6% | 31,6% | **1.552.494 €** |
| marketplace | 34,5% | 12,3% | 53.731 € |

Wholesale pasa de ser el canal más rentable del dataset a **destruir valor**.
Marketplace se queda en un tercio del margen que aparentaba. Los dos canales que
Alohas controla de verdad —tienda y web— no se mueven, y ahí está la lectura de
negocio: **online es el motor**, en euros y con el escenario realista puesto.

El matiz obligatorio: el coste de producto en este dataset es muy alto para moda
(alrededor del 52% del ingreso sin IVA en la base costada). El resultado adverso
de wholesale viene tanto del 45% asumido como de un COGS sintético inverosímil.
Si no se dice, el escenario parece un truco.

---

## 5. Por categoría: quién deja más de cada euro

Por canal el margen se mueve por impuesto y por devoluciones. Por categoría se
mueve por el **mix de costes**: el mismo ingreso neto se parte en producto,
transporte, devolución y lo que queda. Ordenadas de peor a mejor CM%, las ocho
categorías van de Accessories (**31,7%**) a Shoes (**40,2%**): casi nueve
puntos de diferencia con el mismo stack de costes.

El gráfico reparte el 100% del ingreso neto de cada categoría. La sección negra
es el margen; las otras tres explican por qué unas dejan más que otras.

[[chart:cm_categorias]]

| Categoría | Ingreso / línea | COGS / ingreso | Transporte / ingreso | CM % | CM / línea |
|---|---:|---:|---:|---:|---:|
| Accessories | 58,68 € | 60,1% | **7,04%** | **31,7%** | 18,58 € |
| Swimwear | 113,15 € | 62,2% | 3,65% | 33,6% | 37,98 € |
| Tops | 86,59 € | 60,8% | 4,77% | 33,6% | 29,10 € |
| Bags | 241,78 € | **63,3%** | 1,71% | 34,7% | 83,91 € |
| Bottoms | 116,70 € | 61,0% | 3,54% | 34,9% | 40,71 € |
| Dresses | 172,11 € | 59,8% | 2,40% | 37,4% | 64,40 € |
| Outerwear | 367,39 € | 60,0% | **1,12%** | 38,7% | **142,15 €** |
| Shoes | 210,76 € | **57,6%** | 1,96% | **40,2%** | 84,70 € |

Tres lecturas del mismo gráfico:

1. **El transporte plano castiga lo barato.** Accessories deja el peor margen
   porque 4,13 €/línea se comen el **7,0%** del ingreso; en Outerwear solo el
   **1,1%**. Es la conversación de umbral de envío gratis y de si merece la
   pena vender accesorios sueltos.
2. **El COGS no es plano.** Bags tiene ticket alto y transporte bajo, pero el
   coste de producto se come el **63,3%** del ingreso y se queda a mitad de
   tabla. Shoes gana el ranking porque el producto cuesta menos (**57,6%**), no
   porque viaje gratis.
3. **Euros y porcentaje no coinciden.** Outerwear no es el mejor CM%, pero deja
   **142 € por línea**; Accessories, 19 €. Quien mire solo el porcentaje se
   pierde dónde está la caja.

---

## 6. Por producto: sano en revenue, enfermo en CM

Outerwear domina la contribución en euros: de los ocho SKUs con más CM, ocho son
abrigos. Pero el ingreso de un SKU no dice si deja dinero. En el gráfico, cada
punto es uno de los 200 productos del catálogo: cuánto factura en el eje
horizontal, qué margen deja en el vertical y cuánta contribución aporta en el
tamaño. La línea es el 36,8% del negocio, y **109 de los 200 SKUs quedan por
debajo**.

[[chart:cm_productos]]

El cuadrante que pide el brief es el de abajo a la derecha: puntos grandes en
ingreso que caen por debajo de la línea. Cruzando el rank de ingreso con el de
margen se ven con nombre y apellidos.

**Quién lidera en ingreso y se cae en CM:**

| SKU | Producto | Ingreso neto | CM % | Rank ingreso | Rank CM | Caída |
|---|---|---:|---:|---:|---:|---:|
| SKU-04081 | LightSkyBlue Equal Bag 4081 | 83.540 € | 22,4% | 23 | 63 | **−40** |
| SKU-04284 | DarkOliveGreen Several Bag 4284 | 93.188 € | 22,7% | 16 | 55 | −39 |
| SKU-05840 | MediumBlue Ago Outerwear 5840 | 115.547 € | 22,7% | 6 | 36 | −30 |
| SKU-05498 | BlueViolet Raw Bag 5498 | 91.796 € | 25,6% | 18 | 45 | −27 |

SKU-05840 es el ejemplo limpio: sexto en ingreso del catálogo, trigésimo sexto
en contribución. En un chart de revenue parece un caballo ganador; aquí deja
22,7 céntimos de cada euro, lejos del 36,8% del negocio.

**Quién no grita en ingreso y sí en margen:**

| SKU | Producto | Ingreso neto | CM % | Rank ingreso | Contribución | Rank CM |
|---|---|---:|---:|---:|---:|---:|
| SKU-05944 | CornflowerBlue Similar Shoe 5944 | 82.180 € | **53,2%** | 26 | **43.733 €** | 9 |
| SKU-07829 | NavajoWhite All Outerwear 7829 | 85.502 € | **50,5%** | 21 | **43.210 €** | 10 |
| SKU-07221 | LightGreen Successful Outerwear 7221 | 67.309 € | **52,2%** | 41 | 35.130 € | 19 |
| SKU-05090 | NavajoWhite Common Bag 5090 | 49.986 € | **54,8%** | 66 | 27.401 € | 32 |

SKU-05090 es el caso extremo: el **mejor margen del catálogo** (54,8%) con el
puesto 66 en ingreso. Ninguno de estos cuatro abre un ranking de revenue y entre
los cuatro dejan 149.475 € de contribución.

Y el líder de ingreso del catálogo, SKU-01813 (*Khaki Other Outerwear 1813*,
135.922 €), baja del puesto 1 al 6 en contribución: sigue sano, pero ya no es el
primero cuando se abre el coste. El que aguanta en los dos rankings es SKU-03014
(*LightSeaGreen Effective Outerwear 3014*): quinto en ingreso con 115.682 € y
segundo en contribución con un 50,4% de margen. Ese sí es un caballo ganador
mire donde mire.

---

## 7. Premisas, límites y puente

**Premisas que mueven el número**

- Transporte = 4,13 €/línea desde el pool referenciado ([D-06](decisiones.md)).
- Devolución = misma tarifa, una vez por línea; prenda no se revende
  ([D-21](decisiones.md), [D-19](decisiones.md)).
- Escenario realista wholesale 45% / marketplace 17,5% en seed, capa aparte
  ([D-18](decisiones.md)).
- Base = solo catálogo; gap del 1,6% declarado ([D-09](decisiones.md)).
- Todo CM es un techo ([D-12](decisiones.md)).

**Lo que esta sección no contesta**

- País o método de envío (el vínculo es ruido).
- A partir de qué comisión o precio de mayorista cada canal deja de ser
  rentable (el “filo”; queda en más tiempo).
- Sensibilidad a “sí se revende” o a devolver al doble: las convenciones están
  declaradas, pero no hay panel de sensibilidad.
- Serie temporal de CM.

**Puente.** La 01 dijo quién crece y por qué el ranking de ingreso engaña. La 02
dijo cómo habría que modelar las devoluciones que llegan tarde. Esta sección
dice **quién deja dinero** con las reglas que el dato permite, y qué cambia
cuando se corrige lo que el dataset no cobra.
