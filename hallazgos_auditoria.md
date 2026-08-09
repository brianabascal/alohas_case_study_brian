# Hallazgos de la auditoría

Lo que sabemos del dataset después de mirarlo con calma, **antes** de modelar
nada. Aquí solo hay hechos medidos, cada uno con un ejemplo real delante para que
se pueda comprobar. Lo que decidimos hacer con ellos está en
[`decisiones.md`](decisiones.md).

Auditoría del 4 de agosto de 2026, ampliada el día 6 y revisada el día 8. Las
consultas están en `analysis/audit/` y sus resultados en `analysis/audit/out/`.

---

## Lo que hay que saber antes de mirar ningún gráfico

**Primero: el ranking de rentabilidad por canal mide dos cosas, y ninguna es la
que parece.** Entre el canal más rentable y el menos rentable hay 22,1 puntos de
margen. De esos, 12,3 son que wholesale no paga IVA y 9,7 son que unos canales
devuelven más que otros. Todo lo demás junto —qué venden, a qué precio, cuánto les
cuesta producirlo y cuánto enviarlo— explica 0,19 puntos, menos que el error de la
propia medición. Un ranking de canales publicado con este dataset no compara
modelos de negocio: compara tratamiento fiscal y propensión a devolver.

**Segundo: el transporte no se puede atribuir a la venta, solo repartir.** El
vínculo entre cada venta y su envío está puesto al azar, y hay una forma de verlo
que no admite réplica: si cada venta hubiera viajado en su propia caja, el
transporte habría costado 421.225 €; en la contabilidad de envíos solo hay
255.078 €. Así que el porte deja de ser un coste de la línea y pasa a ser una
factura común que se reparte: 206.339 € entre 50.000 líneas, **4,13 € cada una**.

**Tercero: el dataset está demasiado limpio para ser real, y eso tiene dos
consecuencias distintas.** No hay ni un descuento en dos años con dos Black Friday
dentro, y el mayorista compra al mismo precio que la web: por eso **todo margen que
salga de aquí es un techo**, no una estimación. Y las devoluciones ya han llegado
todas —la tasa es plana hasta el último mes—, así que el sesgo de las devoluciones
tardías del que avisa el brief **aquí no se puede medir: hay que simularlo**.

**Cuarto: hay tres agujeros de integridad, todos acotados.** El 1,6% de la
facturación vende artículos que no existen en el catálogo, el 1% de las ventas
apunta a un envío que no existe, y el 19% de los envíos no lo reclama ninguna
venta (48.740 € que no se pueden imputar a nadie). Y hay una ausencia que no es un
agujero sino un límite: **el coste de una devolución no está en el dataset**,
aunque la pregunta 03 lo pida, así que se calcula con una convención declarada
—cuesta lo mismo traer la prenda que enviarla— y no con un dato.

---

## 1. Foto del dataset

Proyecto `alohas-recruiting-study-case`, dataset `production`, región EU.

| Tabla | Filas | Grano | Notas |
|---|---|---|---|
| `fct_sale_order_line` | 50.000 | una fila por línea de pedido | Sin clave primaria |
| `fct_shipment` | 30.000 | una fila por envío | La clave es `shipment_id` |
| `dim_product` | 200 | una fila por artículo | Sin fechas de vigencia |

**Ventana:** del 29 de mayo de 2024 al 29 de mayo de 2026. Esa última fecha es el
corte, y hace falta saberla para poder hablar de madurez de devoluciones.

**Las columnas son exactamente las nueve que anunciaba el brief.** No hay ninguna
columna oculta, ni un número de pedido escondido:

| Tabla | Columnas |
|---|---|
| `dim_product` | `sku`, `name`, `category`, `base_price`, `cost` |
| `fct_shipment` | `shipment_id`, `shipping_method`, `shipping_cost`, `country` |
| `fct_sale_order_line` | `channel`, `sku`, `shipment_id`, `quantity_sold`, `quantity_returned`, `gross_sale`, `taxes`, `net_sales`, `created_at` |

**Cómo se reparte el negocio:**

| Canal | Líneas | % | Unidades | Devuelve | Facturación |
|---|---|---|---|---|---|
| online | 30.066 | 60,1% | 38.684 | 17,9% | 7.687.810 € |
| retail | 9.985 | 20,0% | 12.852 | 13,4% | 2.541.120 € |
| wholesale | 7.393 | 14,8% | 9.555 | 4,2% | 1.889.540 € |
| marketplace | 2.556 | 5,1% | 3.300 | 14,4% | 652.810 € |

Ocho categorías (Dresses, Outerwear, Bottoms, Bags, Shoes, Swimwear, Accessories,
Tops), ocho países de envío (ES, FR, DE, US, IT, UK, PT, MX) y cinco métodos de
envío (standard, express, next_day, economy, pickup).

**Lo que el brief anunciaba y se cumple:** hay pico de noviembre y diciembre
(diciembre de 2025 llegó a 3.200 líneas contra una base de 2.100), hay crecimiento
año contra año (junio de 2025 un 20% por encima de junio de 2024), las
devoluciones se concentran en online y wholesale tiene un tratamiento fiscal
distinto.

---

## 2. Lo que está sano y se puede usar sin miedo

- **No hay filas duplicadas.** Las 50.000 son distintas entre sí.
- **La resta del impuesto cuadra siempre.** El ingreso sin IVA es exactamente la
  venta menos el impuesto en las 50.000 filas, así que la escalera de ingresos se
  apoya en terreno firme.
- **Nadie devuelve más de lo que compró**, y no hay cantidades negativas ni a cero.
- **No hay ni un valor nulo** en ninguna columna de ninguna tabla.
- **El catálogo es coherente:** ningún artículo cuesta más de lo que se vende, los
  márgenes brutos por categoría van del 45% al 70% y los precios son plausibles
  (accesorios de 30 a 120 €, abrigos de 200 a 550 €).
- El clásico problema plantado a propósito de "producto que se vende por debajo de
  coste" **no está** en este dataset. Los que hay son otros.

---

## 3. Lo que el dataset no contiene

Antes de los problemas, la lista de ausencias. Ninguna es un error: son cosas que
simplemente no están, y cada una limita una respuesta.

- **No hay número de pedido.** Ni de pedido ni de línea. Sin eso no hay ticket
  medio por pedido ni prendas por cesta.
- **No hay descuentos ni promociones.** El importe facturado es siempre el precio
  de catálogo por las unidades. En dos años de moda, con dos Black Friday dentro.
- **No hay comisión de canal.** Marketplace se queda el 100% de lo que factura,
  cuando en la realidad Zalando o Amazon se llevan entre el 15% y el 20%. Es justo
  el coste que en la vida real diferencia a ese canal.
- **No hay fecha de devolución.** La devolución es un contador dentro de la línea
  de venta, sin momento en el tiempo.
- **No hay coste de devolución**, aunque la pregunta 03 del brief pida incluirlo.
  No falta una columna: falta la entidad entera.
- **No hay historia de precios ni de costes.** El catálogo es una foto de hoy sin
  fechas de vigencia, así que una venta de 2024 se coste con el coste actual.
- **No hay destino real de la venta.** El país está en el envío, y el vínculo con
  el envío es azar (ver DQ-11).

---

## 4. Los problemas de calidad

Once hallazgos, con la numeración con la que se fueron encontrando.

### [DQ-01] 722 artículos vendidos no existen en el catálogo

**Qué pasa.** 750 líneas venden artículos que no tienen ficha en `dim_product`.
Son 722 códigos distintos y suman **203.240 €, el 1,6% de la facturación**.

**El ejemplo.** Se vende `SKU-90001`. En el catálogo solo hay códigos del estilo
`SKU-01065`. Todos los huérfanos viven en el rango `SKU-9xxxx`: no es ruido
aleatorio, es **otro espacio de nombres**. Se reparten proporcionalmente entre los
cuatro canales y a lo largo de los dos años, con las mismas unidades por línea que
el resto. Lectura de negocio: parece un fallo de sincronización entre el maestro
de producto y el sistema de ventas, del tipo "se dieron de alta artículos en la
tienda que nunca llegaron al catálogo maestro".

**Por qué importa.** Sin ficha no hay coste de producto, y sin coste no hay
margen. Esas ventas no pueden entrar en el cálculo de rentabilidad, y tampoco se
pueden rellenar con la media de su categoría, porque tampoco tienen categoría.

**Qué se decidió.** Salen del mart de margen y se publica cuánto dinero queda
fuera ([D-09](decisiones.md)).

### [DQ-02] 500 ventas apuntan a un envío que no existe

**Qué pasa.** El 1,00% de las líneas (0,96% de la facturación) apunta a un
identificador de envío que no está en la tabla de envíos. Son 499 identificadores
distintos.

**El ejemplo.** Una venta online del 29 de mayo de 2024, de 560 €, apunta al envío
`SHP-9814827`. Ese envío no existe. Y aquí hay un detalle que no es casualidad:
los envíos reales tienen códigos del tipo `SHP-0010294`, y **los rotos empiezan
todos por 9**, igual que los artículos huérfanos de DQ-01. Es el mismo artefacto
del generador aplicado a dos tablas distintas.

**Por qué importa, y por qué al final no importa.** Sobre el papel son ventas sin
coste de envío asignable. Pero como el transporte se reparte a tarifa plana, estas
500 líneas cargan sus 4,13 € como todas las demás y el total sigue cuadrando al
céntimo. El problema se disuelve solo ([D-06](decisiones.md)).

### [DQ-03] 5.758 envíos que ninguna venta reclama

**Qué pasa.** El **19,2%** de la tabla de envíos —5.758 paquetes por valor de
**48.739,92 €**— no aparece referenciado por ninguna línea de venta.

**El ejemplo.** El envío `SHP-0010840` es un `next_day` a España que costó
24,97 €. Alguien lo pagó. Ninguna venta del dataset lo menciona.

**Por qué importa.** Si alguien suma el gasto de transporte desde la tabla de
envíos y se lo carga a las ventas, **se cree un 19% más pobre de lo que es**. El
gráfico sale bonito y falso, y nadie lo detectaría mirando el dashboard.

**Qué son, y por qué se preguntó.** En una marca de moda un paquete sin venta
asociada normalmente tiene nombre: devolución que entra, cambio, reposición a
tienda, muestra a prensa. Y el nombre importaba mucho, porque si fueran logística
inversa, el dataset **sí** contendría el coste de devolución que la pregunta 03
exige. Se preguntó a Alohas y la respuesta fue clara: **no son devoluciones**. Los
datos tampoco permiten clasificarlos por su cuenta, porque su mezcla de métodos de
envío, su mezcla de países y su coste medio por paquete son indistinguibles de los
envíos que sí tienen venta. Se quedan sin explicación, y no hace falta dársela
para poder modelar.

**Qué se decidió.** Esos 48.739,92 € **no cuentan como coste de envío**. El
transporte se calcula siempre desde el lado de las ventas, nunca sumando la tabla
de envíos ([D-06](decisiones.md)). La cifra se declara para que nadie confunda el
total de la tabla con el gasto imputable, pero no toca ningún margen.

### [DQ-04] El identificador de envío no agrupa cajas reales

**Qué pasa.** Uno esperaría que un `shipment_id` fuera una caja saliendo del
almacén. No lo es.

- De los 24.741 envíos que aparecen en las ventas, el 40,7% tiene una sola línea;
  el resto llega hasta nueve.
- Entre los que tienen dos líneas, **el 99,8% abarca días distintos** (7.769 de
  7.782). Una caja no puede salir del almacén en dos fechas.
- La mezcla de canales dentro de un mismo envío coincide con lo que produciría el
  azar puro. Si las líneas se hubieran asignado a envíos tirando un dado, el 57,4%
  de los envíos de dos líneas mezclaría canales; el observado es el 57,9%.

**El ejemplo.** El envío `SHP-0010294` agrupa siete líneas: la primera del **29 de
mayo de 2024** y la última del **28 de mayo de 2026**. Setecientos veintinueve días
dentro de la misma "caja", mezclando venta online, tienda física y mayorista. Los
cinco peores casos superan todos los 720 días.

**Por qué importa.** Dos cosas. Una, `shipment_id` no sirve como sustituto de
"pedido", así que las métricas de pedido quedan fuera de alcance
([D-05](decisiones.md)). Y dos, cualquier reparto del porte entre las líneas de un
mismo envío es una convención de asignación, no la reconstrucción de un coste real.

### [DQ-05] Un IVA del 21% clavado en ocho países, incluidos Estados Unidos y México

**Qué pasa.** El impuesto es exactamente el 21,00% de la venta en los ocho países.
Wholesale lleva el 0%.

**El ejemplo.** Una venta online de 2.200 € con destino a **México** pagó 462 € de
impuesto: el 21,00% redondo. Otra de 2.200 € a **Estados Unidos**, lo mismo.

**Por qué está mal.** Francia aplica el 20%, Alemania el 19%, Italia el 22% y
Portugal el 23%. Estados Unidos no tiene IVA en absoluto y México aplica el 16%.
Aquí se está facturando un impuesto europeo a destinos que no lo llevan.

**Por qué importa.** Ese 21% es una constante aplicada en origen, no un impuesto
de destino. Quitar el IVA a nivel global es correcto; hacerlo país por país no
significa nada. Confirma además que el precio de catálogo lleva el IVA dentro
([D-13](decisiones.md)).

**Detalle menor de la misma familia (DQ-07).** El Reino Unido aparece como `UK`
cuando el código internacional es `GB`. No cambia ninguna cifra, pero rompe
cualquier cruce con tablas de países estándar, así que se normaliza al cargar
([D-11](decisiones.md)).

### [DQ-06] Cero descuentos en dos años, y el mayorista comprando a precio de tienda

**Qué pasa.** El importe facturado es siempre el precio de catálogo multiplicado
por las unidades. En el **100,00%** de las filas, en los cuatro canales, sin una
sola excepción en 24 meses.

**El ejemplo.** Un vestido de catálogo a 100 €. Si vendes dos, el importe es
siempre 200,00 €. Nunca 180 €. Y en wholesale también: el mismo precio de
escaparate, con impuesto cero.

**Dos consecuencias de negocio, y las dos son grandes:**

1. **No hay ni una promoción en dos años de retail de moda**, con dos Black Friday
   dentro y el pico de noviembre y diciembre que el propio brief anuncia. Eso no
   es un dataset limpio, es un dataset **incompleto**. Todo margen que se calcule
   aquí es un techo.
2. **El mayorista compra a precio de escaparate.** En la vida real compra al
   40–50%. Combinado con el impuesto cero, wholesale va a parecer el canal más
   rentable por pura construcción del dato. Es la trampa central de la pregunta 01.

**El orden de magnitud, hecho en una servilleta.** Hoy el margen bruto de
wholesale ronda el 57%. Comprando al 50% del precio de tienda caería al 15%. Al
40%, **pierde dinero por cada prenda**.

**Un efecto colateral que hay que decir.** Como el precio nunca se mueve, tampoco
se puede detectar si el catálogo ha derivado. El riesgo de estar costeando ventas
de 2024 con el coste de hoy queda abierto y sin forma de medirlo
([D-12](decisiones.md)).

### [DQ-08] Las devoluciones tardías del brief no están en los datos

**Qué pasa.** El brief avisa de que las devoluciones llegan entre 30 y 90 días
después de la venta, y de que por eso un dashboard construido hoy *"empezaría a
mentir el trimestre siguiente"*. **En estos datos eso no se ve.**

**El ejemplo.** La tasa de devolución por mes de venta es plana en los 25 meses,
alrededor del 14,8%, moviéndose entre el 13,4% y el 16,2%, que es ruido de
muestreo. Y mayo de 2026 —vendido a menos de un mes del corte del dataset— marca
**15,2%, por encima de la media**. Si las devoluciones tardaran de verdad 30 a 90
días, ese mes debería estar casi a cero.

**Conclusión.** El generador materializó las devoluciones en el instante de la
venta. Lo que tenemos es una foto completamente madura, no un corte vivo.

**Qué significa para la sección 02.** El sesgo del que avisa el brief es real como
riesgo futuro, pero **aquí no se puede medir: hay que simularlo**. La sección 02 es
diseño más simulación, no demostración empírica, y decirlo en voz alta es la
prueba de haber auditado. La trampa no es un dato malo: es un dato demasiado
limpio.

### [DQ-09] El porte es una tarifa por método, no el coste de lo que va dentro

**Qué pasa.** Lo que cuesta un envío no depende de lo que lleva dentro.

**El ejemplo.** Un paquete `standard` con una sola prenda costó **5,26 €**. Otro
paquete `standard` con ocho prendas costó **6,61 €**. Siete prendas más por 1,35 €.
Y en media, el coste por envío es prácticamente idéntico tenga una línea o nueve:

| Líneas en el envío | Envíos | Coste medio | Unidades medias |
|---|---|---|---|
| 0 (los huérfanos) | 5.758 | 8,46 € | — |
| 1 | 9.559 | 8,46 € | 1,28 |
| 2 | 7.781 | 8,57 € | 2,57 |
| 3 | 4.317 | 8,53 € | 3,88 |
| 4 | 1.772 | 8,53 € | 5,15 |

Lo que sí determina el precio es **el método**, con algo de ruido dentro de una
banda. El país de destino no mueve la media ni una décima:

| Método | Media | Rango observado |
|---|---|---|
| pickup | 0,00 € | exacto |
| economy | 4,00 € | 2,99–4,99 |
| standard | 6,49 € | 4,99–7,99 |
| express | 12,49 € | 9,99–14,99 |
| next_day | 19,94 € | 15,00–24,99 |

**Por qué esto entierra el debate del reparto.** Si el coste no crece con las
unidades, repartirlo "proporcional a las unidades vendidas" no tiene ninguna base
física. El porte es un coste **por expedición**, y lo que el dataset no permite
saber es cuántas expediciones generó un conjunto de líneas. La incógnita nunca fue
el criterio de reparto: es el número de cajas. DQ-11 la cierra por el lado del
dinero.

**Lo único que el método sí explica, y que ningún reparto puede darte.** Al nivel
del paquete, donde el método es un hecho y no un atributo heredado al azar, la
factura se reparte así:

| Método | % de paquetes | % de la factura |
|---|---|---|
| standard | 54,8% | 41,9% |
| express | 20,1% | 29,5% |
| next_day | 10,3% | **24,0%** |
| economy | 9,8% | 4,6% |
| pickup | 5,0% | 0% |

**El 10% de los paquetes se lleva el 24% del gasto de transporte.** Es la única
conclusión logística accionable que soporta este dataset, y no necesita repartir
nada.

### [DQ-10] El canal no es una dimensión de negocio, es casi una etiqueta

**Qué pasa.** Los cuatro canales tienen tamaños muy distintos, pero venden el
mismo surtido, al mismo precio, con el mismo coste de producción y con la misma
mezcla de métodos de envío. Lo único que cuelga de verdad de la etiqueta del canal
es **si paga impuesto** y **cuánto devuelve**.

**El ejemplo.** El artículo `SKU-05840`, un abrigo del catálogo, se vende en los
cuatro canales exactamente al mismo precio: 450,00 € por unidad en online, en
retail, en wholesale y en marketplace. No es una excepción: los cuatro canales
venden los 200 artículos del catálogo, los 200, en las mismas proporciones.

**Por qué importa.** Cualquier ranking de rentabilidad por canal publicado con
este dataset mide dos cosas y solo dos: quién paga IVA y quién devuelve. La
medición completa está en la [sección 5](#5-los-cuatro-canales-qué-los-diferencia-de-verdad),
porque es el hallazgo que gobierna la respuesta a las preguntas 01 y 03 y merece
su propio sitio.

### [DQ-11] Las cajas que harían falta cuestan un 65% más de lo que hay

**Qué pasa.** Una caja no puede salir del almacén dos días distintos. Si contamos
cuántas cajas hacen falta como mínimo para que las fechas cuadren, salen **49.445
cajas sobre 49.500 líneas con envío**: solo 55 líneas de 49.500 comparten envío
*y* día con otra. La consolidación que insinúa el identificador de envío es
imposible en el 99,9% de los casos.

Y esas cajas mínimas, cobradas cada una a la tarifa de su método, **costarían
421.225 €**. El libro entero de envíos contiene **255.078 €**.

| Concepto | Paquetes | Coste |
|---|---|---|
| Todo lo que hay en la tabla de envíos | 30.000 | 255.078,42 € |
| — de eso, lo que alguna venta menciona | 24.242 | 206.338,50 € |
| — de eso, lo que nadie menciona (DQ-03) | 5.758 | 48.739,92 € |
| Cajas mínimas que exigen las fechas | 49.445 | 421.224,86 € |

**Por qué importa.** Las dos últimas filas no pueden ser verdad a la vez. O el
vínculo entre venta y envío es real, y entonces la contabilidad de envíos no
registra ni dos tercios del gasto; o la contabilidad es correcta, y entonces el
vínculo es ruido. DQ-04 ya había contestado cuál de las dos por el lado de las
fechas; esto lo confirma por el lado del dinero, que es el idioma que entiende un
director financiero.

**Y si el vínculo es ruido, el país también.** El destino es un dato del envío que
la venta hereda por ese mismo vínculo aleatorio, y el propio dato lo delata: hay
**254 envíos con recogida en tienda a Estados Unidos y México**, para una marca
que opera desde Barcelona. Y un `next_day` a Estados Unidos cuesta de media
19,99 € contra 19,76 € dentro de España: cruzar el Atlántico sale igual que cruzar
Barcelona.

**Conclusión: ninguna venta de este dataset tiene destino observable**, así que
cualquier corte geográfico queda fuera del report o se marca como no
interpretable. Y matiza lo de DQ-05: más que "facturan IVA europeo a destinos que
no lo llevan", lo que ocurre es que el destino no significa nada.

---

## 5. Los cuatro canales: qué los diferencia de verdad

La pregunta 01 pide un ranking de canales y la 03 pide rentabilidad por canal.
Antes de publicar ninguna de las dos hay que saber **qué está midiendo** ese
ranking. Esta sección lo mide.

Entre el canal más rentable y el menos rentable hay 22,1 puntos de margen. La
escalera de abajo los apaga uno a uno: cada fila neutraliza un efecto y enseña
cuánto quedaba debajo.

| Lectura del margen | wholesale | retail | marketplace | online | Diferencia |
|---|---|---|---|---|---|
| Tal como sale del dato | 53,74% | 34,90% | 34,48% | 31,60% | **22,1 pts** |
| …poniendo el 21% de IVA a los cuatro | 41,44% | 34,90% | 34,48% | 31,60% | **9,8 pts** |
| …y además sin efecto de la devolución | 43,91% | 43,73% | 43,72% | 43,74% | **0,19 pts** |

Leído de arriba abajo: **12,3 puntos son impuestos, 9,7 son devoluciones y 0,19 es
todo lo demás junto** —surtido, precio, coste de producción y logística—. Y esos
0,19 puntos ni siquiera llegan al margen de error de la propia medición, así que
no son una diferencia: son ruido.

Los tres apartados siguientes son la prueba de cada renglón.

### 5.1 Venden lo mismo, al mismo precio y con el mismo coste

| Canal | Líneas | Artículos distintos | Uds/línea | Precio por línea | Coste por línea | Coste/precio |
|---|---|---|---|---|---|---|
| online | 29.631 | 200 | 1,287 | 255,42 € | 108,45 € | 42,46% |
| retail | 9.819 | 200 | 1,288 | 254,41 € | 108,21 € | 42,53% |
| wholesale | 7.281 | 200 | 1,294 | 255,29 € | 108,77 € | 42,61% |
| marketplace | 2.519 | 200 | 1,291 | 255,19 € | 108,61 € | 42,56% |

(El recuento excluye los artículos sin ficha de DQ-01, que no tienen coste con el
que comparar.)

Los cuatro canales venden **los 200 artículos del catálogo, los 200**. El coste de
producción por línea separa como mucho 56 céntimos entre el canal más caro y el
más barato, y el precio por línea separa como mucho un euro. Las dos diferencias
son **más pequeñas que el margen de error con el que están medidas** —el error de
la diferencia de coste es de 1,47 € y el de precio de 2,57 €—, así que son
indistinguibles de cero.

Y el surtido coincide igual de bien. Así se reparte cada canal entre las ocho
categorías:

| Categoría | online | retail | wholesale | marketplace |
|---|---|---|---|---|
| Dresses | 18,03% | 17,98% | 18,12% | 17,43% |
| Outerwear | 14,56% | 14,49% | 13,86% | 13,97% |
| Bottoms | 12,80% | 13,06% | 12,77% | 13,66% |
| Bags | 12,40% | 13,02% | 12,06% | 12,50% |
| Shoes | 10,88% | 11,15% | 11,50% | 11,19% |
| Swimwear | 10,98% | 10,66% | 11,34% | 11,12% |
| Accessories | 10,72% | 10,50% | 10,62% | 10,76% |
| Tops | 9,64% | 9,15% | 9,74% | 9,37% |

Mirar dos columnas y decir "se parecen" no es una prueba, así que se hizo el test
formal. Lo que dice, en cristiano: **si el canal no influyera absolutamente nada
en lo que se vende, el azar produciría de media más diferencia entre columnas de
la que estamos viendo.** Ningún canal se desvía del reparto global más de 0,77
puntos porcentuales. (Para quien quiera el respaldo: chi-cuadrado de 14,69 con 21
grados de libertad, p = 0,84.)

**Conclusión.** Un canal mayorista que vende la misma proporción de bañadores que
la tienda física no existe en el mundo real. Las líneas de los cuatro canales
salen de la misma chistera; lo único que cambia es cuántas saca cada uno. Ni el
surtido, ni el precio, ni el coste de producción pueden explicar ninguna
diferencia de rentabilidad entre canales.

### 5.2 También los envían igual, y por eso el criterio de transporte da igual

Así se reparte cada canal entre los métodos de envío:

| Método | Tarifa | online | retail | wholesale | marketplace |
|---|---|---|---|---|---|
| standard | 6,49 € | 54,66% | 53,41% | 54,63% | 54,73% |
| express | 12,49 € | 19,64% | 20,86% | 19,79% | 19,76% |
| next_day | 19,94 € | 10,28% | 9,95% | 10,35% | 9,98% |
| economy | 4,00 € | 9,38% | 9,88% | 9,02% | 9,23% |
| pickup | 0,00 € | 5,03% | 4,90% | 5,21% | 5,40% |
| sin envío (DQ-02) | — | 1,01% | 0,99% | 1,00% | 0,90% |

Mismo test, misma respuesta: **el canal tampoco predice cómo se envía**, con una
desviación máxima de un punto porcentual (p = 0,49). Y los cuatro agrupan sus
líneas en envíos del mismo tamaño —entre 2,62 y 2,65 líneas por envío—, así que
cualquier criterio de reparto los trata exactamente igual.

**Por eso la decisión de cómo repartir el transporte es inocua por canal.** No
mueve el ranking, elijamos el criterio que elijamos.

**Pero por categoría no es inocua en absoluto, y ese sí es un hallazgo.** El porte
es una constante de 4,13 € por línea, y una constante pesa muchísimo más sobre lo
barato:

| Categoría | Ingreso neto por línea | El transporte le pesa |
|---|---|---|
| Outerwear | 429,53 € | 0,96% |
| Bags | 282,06 € | 1,46% |
| Shoes | 244,66 € | 1,69% |
| Dresses | 202,23 € | 2,04% |
| Bottoms | 137,16 € | 3,01% |
| Swimwear | 130,47 € | 3,16% |
| Tops | 101,51 € | 4,07% |
| Accessories | 68,78 € | **6,00%** |

**Enviar un accesorio se come seis veces más margen que enviar un abrigo.** Es la
misma constante leída al revés: 4,13 € sobre un accesorio de 69 € es mucho dinero;
sobre un abrigo de 430 €, calderilla. Por canal el transporte no explica nada; por
categoría explica un gradiente de seis a uno, y ahí sí hay una conversación de
negocio que tener —sobre umbral de envío gratis, sobre agrupar pedidos pequeños o
sobre si merece la pena vender accesorios sueltos.

### 5.3 Lo único que los separa: el impuesto y la devolución

Descartados el surtido y la logística, quedan exactamente dos variables con
valores distintos por canal:

| Canal | Impuesto | Devuelve |
|---|---|---|
| online | 21% | 17,90% |
| marketplace | 21% | 14,46% |
| retail | 21% | 13,39% |
| wholesale | **0%** | **4,17%** |

La escalera del principio de esta sección las apaga por turnos. Ponerle el 21% a
wholesale le quita 12,3 puntos y con eso desaparece más de la mitad de su ventaja.
Quitar después el efecto de la devolución borra los 9,7 restantes y deja a los
cuatro canales dentro de dos décimas. No queda ninguna tercera variable a la que
atribuir nada.

**Y hay una condición escondida en el segundo peldaño que decide media
conclusión.** La cesta que se devuelve tiene el mismo ratio coste/precio que la
que se vende:

| Canal | Coste/precio de lo vendido | Coste/precio de lo devuelto |
|---|---|---|
| online | 42,46% | 42,36% |
| retail | 42,53% | 42,25% |
| wholesale | 42,61% | 42,20% |
| marketplace | 42,56% | 42,46% |

Como son iguales, si la prenda devuelta volviera al almacén y se vendiera otra
vez, devolver restaría ingreso y coste en la misma proporción y **el margen
porcentual ni se enteraría**: los cuatro canales quedarían empatados en el entorno
del 43,7%. Los 9,7 puntos que la devolución explica existen **porque hemos asumido
que la prenda devuelta no se revende** ([D-19](decisiones.md)). Es una convención,
está declarada, y hay que publicarla al lado del número.

**Lo que el dataset le regala a wholesale y a marketplace.** Los dos canales que
en la vida real pagan un peaje, aquí no lo pagan: wholesale factura a precio de
escaparate y no existe ningún campo de comisión de marketplace. Las dos ausencias
empujan en la misma dirección —inflan el margen de los dos canales que en la
realidad pagarían— y una de ellas beneficia justo al que lidera el ranking. Por
eso el report publica también un escenario con esos dos costes puestos
([D-18](decisiones.md)), y ahí wholesale pasa de primero a **destruir valor**.

### 5.4 Nota: el subconjunto de envíos de una sola línea

Es el único sitio donde el vínculo entre venta y envío no está desmentido, y
resulta ser un espejo casi perfecto del total:

| | Envíos de 1 línea | El resto |
|---|---|---|
| Líneas | 9.559 (19,1%) | 39.941 |
| Facturación | 2,43 M€ | 10,22 M€ |
| Reparto por canal | 59,8 / 20,1 / 14,8 / 5,3 | 60,2 / 19,9 / 14,8 / 5,1 |
| Unidades por línea | 1,282 | 1,290 |
| Tasa de devolución | 14,64% | 14,83% |
| Importe por línea | 254,32 € | 255,83 € |

**Cuidado con la tentación de refugiarse aquí.** Que una línea esté sola en su
envío **no demuestra que viajara sola**: la asignación es igual de arbitraria en
los dos grupos, solo que en este no tenemos evidencia que la contradiga.
Restringir el report a este subconjunto no compra verdad, compra ausencia de
reparto, y cuesta el 81% de la facturación. Su uso correcto es como **grupo de
control**, para comprobar que el margen calculado sobre el total no se desvía.

---

## Referencias

Las consultas están numeradas en `analysis/audit/` y sus resultados en
`analysis/audit/out/`. Las que sostienen esta sección 5, por bloque:

- Composición por canal: `21_`, `22_`, `23_`, `26_`
- Logística: `22_`, `24_`
- Impuesto y devoluciones: `25_`
- Márgenes y escenario: `29_margen_por_canal_y_escenario`
- El transporte como pool: `27_expediciones_pool_y_minimo` (DQ-11) y
  `28_que_son_los_envios_huerfanos` (DQ-03)
- Los ejemplos concretos de este documento: `31_ejemplos_para_el_documento`

Las decisiones que salen de todo esto: [`decisiones.md`](decisiones.md).
