# 01 — Ventas por canal

> *How is the business performing across channels?* — pregunta 1 del brief

El negocio creció un **21,2%** en ingreso neto en el último año, y ese crecimiento
es de vender más, no de vender más caro. Pero antes de ordenar los canales hay que
decidir qué se está midiendo, porque **el ranking cambia según el peldaño en el que
lo mires**: retail cobra 651.580 € más que wholesale y acaba ingresando 75.095 €
menos que él. Esa vuelta de tortilla no es un detalle contable, es la respuesta a
la pregunta que hace el brief sobre si estamos comparando peras con peras.

Dos avisos que gobiernan todo lo que viene después. El primero: ningún canal está
creciendo en ventas y quedándose igual en ingreso. Miramos canal por canal si las
devoluciones se están comiendo el crecimiento, partiendo los dos años en cuatro
tramos, y **las cuatro tasas terminan donde empezaron**. El segundo, y es el
importante: este ranking mide dos cosas,
y ninguna de las dos es el modelo de negocio. Mide **quién paga IVA y quién
devuelve**. Todo lo demás —qué venden, a qué precio, con qué coste y con qué
logística— es indistinguible entre los cuatro canales.

---

## 1. Antes de ordenar nada: qué llamamos "ventas"

El dataset trae un campo llamado `net_sales` que **no es** neto de devoluciones: es
la venta menos el impuesto. El nombre engaña, y con él se cometería el error clásico
de esta pregunta, porque wholesale factura con impuesto cero. Comparar canales por
ese campo es poner a un canal sin IVA a competir contra tres que lo llevan dentro.

Así que el report se titula con el **ingreso neto**: sin impuesto y descontando lo
que el cliente devolvió.

[[chart:escalera]]

De cada 100 € que Alohas cobró en estos dos años, **70,28 € son ingreso neto**. El
impuesto se lleva 17,89 € y las devoluciones otros 11,83 €.

| Peldaño | Importe | Qué es |
|---|---:|---|
| Importe cobrado | 12.771.280 € | Lo que pagó el cliente, con el impuesto dentro |
| − Impuestos | −2.285.165 € | El 21% en tres canales, cero en wholesale |
| = Ingreso sin IVA | 10.486.115 € | El campo `net_sales` del dataset |
| − Valor de lo devuelto | −1.510.382 € | El 14,4% de lo anterior |
| **= Ingreso neto** | **8.975.733 €** | **El titular de este report** |

## 2. El ranking cambia tres veces, y esa es la respuesta

Cada peldaño de esa escalera reordena los canales, porque cada uno castiga a un
canal distinto. Este es el mismo negocio mirado tres veces:

[[chart:peldanos]]

| Canal | Cuota de lo cobrado | Cuota sin IVA | Cuota de ingreso neto | Devuelve (unidades) |
|---|---:|---:|---:|---:|
| online | 60,20% | 57,92% | 55,58% | 17,90% |
| retail | 19,90% | 19,14% | 19,33% | 13,37% |
| wholesale | 14,80% | 18,02% | **20,16%** | 4,15% |
| marketplace | 5,11% | 4,92% | 4,94% | 14,42% |

**Wholesale sube 5,4 puntos de cuota entre el primer peldaño y el último** y
adelanta a retail por el camino. No ha vendido ni una prenda más: simplemente no
paga impuesto y devuelve cuatro veces menos que el resto. En euros, retail cobra
2.541.120 € contra los 1.889.540 € de wholesale —le saca 651.580 €— y termina en
1.734.595 € de ingreso neto contra 1.809.690 €, o sea 75.095 € por debajo. Un
vuelco de 726.675 € que ocurre entero dentro de la escalera.

> **Cuidado con leer esto como que wholesale es el mejor canal.** En este dataset
> el mayorista compra al mismo precio que la web, cosa que no pasa en el mundo
> real, donde compra al 40–50% del precio de escaparate. Su cuota de ingreso está
> inflada por construcción del dato. La corrección, con el escenario puesto, está
> en la sección 03; aquí se publica lo que dice el dato sin tocar.

## 3. Cómo va el negocio: crece un 21,2%, y crece vendiendo más

Comparamos dos ventanas de 365 días terminadas en la fecha de corte, no dos años
naturales, para que los periodos midan lo mismo.

[[chart:mensual]]

| | Año 1 | Año 2 | Variación |
|---|---:|---:|---:|
| Ingreso neto | 4.051.072 € | 4.908.082 € | **+21,16%** |
| Unidades vendidas | 29.294 | 34.960 | +19,34% |
| Ingreso sin IVA por unidad | 161,86 € | 163,71 € | +1,14% |

Casi todo el crecimiento es **volumen**: se venden 5.666 unidades más. El ingreso
por unidad sube un 1,14%, y aquí conviene no confundirse: en este dataset **el
precio de catálogo nunca se mueve y no hay ni un descuento en dos años**, así que
ese 1,14% no puede ser una subida de precios. Es mezcla: se está vendiendo un poco
más de lo caro.

| Categoría | Cuota de unidades año 1 | Año 2 | Cambio | Ingreso por unidad |
|---|---:|---:|---:|---:|
| Shoes | 10,57% | 11,35% | **+0,78 pp** | 191,60 € |
| Outerwear | 14,10% | 14,75% | **+0,64 pp** | 333,20 € |
| Bottoms | 13,05% | 12,90% | −0,15 pp | 106,21 € |
| Bags | 12,42% | 12,41% | −0,01 pp | 219,33 € |
| Swimwear | 11,01% | 10,99% | −0,02 pp | 100,94 € |
| Accessories | 10,86% | 10,73% | −0,13 pp | 52,49 € |
| Tops | 9,71% | 9,23% | −0,49 pp | 78,86 € |
| Dresses | 18,26% | 17,65% | −0,62 pp | 157,25 € |

Las dos categorías que ganan cuota son las dos más caras del catálogo —zapatos a
192 € y abrigos a 333 € por unidad— y las que la pierden son camisetas a 79 € y
vestidos. Es un movimiento pequeño, de menos de un punto, pero va todo en la misma
dirección y explica el euro y medio que sube el ticket por unidad.

## 4. Quién crece, y si a alguno se le queda el crecimiento en las devoluciones

[[chart:crecimiento]]

| Canal | Ingreso neto año 1 | Año 2 | Crecimiento | % del crecimiento total |
|---|---:|---:|---:|---:|
| online | 2.238.054 € | 2.741.245 € | +22,48% | **58,7%** |
| wholesale | 825.320 € | 981.000 € | +18,86% | 18,2% |
| retail | 788.112 € | 942.296 € | +19,56% | 18,0% |
| marketplace | 199.586 € | 243.541 € | +22,02% | 5,1% |

Los cuatro canales crecen, y crecen parecido: entre el 18,9% y el 22,5%. Como
consecuencia, **la mezcla de canales prácticamente no se mueve**: online pasa del
55,25% al 55,85% del ingreso neto, wholesale del 20,37% al 19,99%, retail del
19,45% al 19,20% y marketplace del 4,93% al 4,96%. Ningún canal se mueve ni un
punto. El *channel mix shift* por el que pregunta el brief, en estos dos años, no
existe.

Lo que sí importa es de dónde salen los euros: **online pone 503.191 € de los
857.010 € que crece el negocio, el 58,7%**. Es el canal grande creciendo un poco
más rápido que la media, y por eso concentra el crecimiento aunque su porcentaje
sea parecido al de los demás.

### ¿Algún canal vende más y no ingresa más?

Un canal puede vender más y quedarse igual si al mismo tiempo le devuelven más. Es
lo que el brief llama *quietly leaks*, y hay que buscarlo a propósito porque no se
ve en el gráfico de ingresos.

Comparar solo dos años no sirve para esto, porque medio año flojo mueve el
resultado del año entero y parece una tendencia. Partimos los dos años en cuatro
medios años y miramos si la línea sube:

[[chart:devoluciones]]

**Ninguna sube de forma sostenida.** Retail es el único al que la comparación anual
le sale mal, con 1,10 puntos más de devolución, y partido en cuatro se ve de dónde
viene: devuelve el **13,90%, el 11,65%, el 13,85% y el 13,86%**. Tres de los cuatro
tramos son prácticamente el mismo número, así que lo que hay no es un deterioro
sino un tramo bajo —el que va de diciembre de 2024 a mayo de 2025— que deja el
primer año artificialmente bueno. Wholesale hace el recorrido contrario, 3,49% →
5,19% → 4,28% → 3,72%, y termina donde empezó.

Aun así, antes de preocuparse por retail conviene ponerle un tamaño a la subida, y
la cuenta es sencilla. Retail vendió 6.970 prendas el segundo año y le devolvieron
el 13,86%, es decir, 966. Si le hubieran devuelto al ritmo del año anterior, el
12,76%, habrían vuelto 889: **77 prendas menos**. Como cada prenda de retail deja
de media 157 € de ingreso, esas 77 prendas valen **12.079 €**.

Esa misma cuenta, en los cuatro canales:

| Canal | Tasa año 1 | Tasa año 2 | Prendas de más o de menos | Lo que cuesta o ahorra |
|---|---:|---:|---:|---:|
| retail | 12,76% | 13,86% | 77 más | cuesta 12.079 € |
| online | 17,87% | 17,90% | 8 más | cuesta 1.302 € |
| marketplace | 14,65% | 14,18% | 8 menos | ahorra 1.331 € |
| wholesale | 4,34% | 3,99% | 18 menos | ahorra 3.505 € |

Sumando los cuatro, el segundo año volvieron al almacén **59 prendas más** de las
que habrían vuelto manteniendo las tasas del año anterior, sobre 34.960 vendidas.
En dinero son **8.545 € de un ingreso neto de 4,9 millones**: el 0,17%.

Así que la respuesta es doble. **Ningún canal está vendiendo más y quedándose igual
en ingreso**, y aunque la subida de retail fuese real, cuesta 12.079 € al año, el
1,3% de lo que ingresa ese canal. Retail sigue siendo el sitio donde mirar primero
—es el único cuyo año completo sale peor que el anterior— pero hoy no hay ahí un
problema que resolver.

## 5. Estacionalidad, y por qué el grano es mensual

Noviembre y diciembre concentran el pico que el brief anunciaba, y lo concentran
**en los cuatro canales por igual**: el 24,7% del año en retail, el 24,1% en
marketplace, el 23,2% en online y el 22,6% en wholesale. Merece un comentario, y no
halagüeño para el dataset: un canal mayorista de verdad vende por campaña y
pre-order, meses antes de la temporada, no en Black Friday. Que wholesale tenga la
misma curva de Navidad que la tienda física es otra señal de que aquí el canal es
casi una etiqueta.

Esa estacionalidad decide el grano. **Diciembre de 2025 hizo 576.713 € de ingreso
neto y enero de 2026 hizo 342.921 €**: una caída del 40,5% que no significa
absolutamente nada, porque enero siempre cae. Comparar un mes con el anterior en
moda es medir la Navidad. Por eso todas las comparaciones de este report son contra
el mismo mes del año anterior.

Y hay un segundo motivo para no bajar del mes. Marketplace hace **24 líneas por
semana** de media, entre 9 y 40: a ese volumen la serie semanal es ruido puro, y su
comparación mensual contra el año anterior salta entre el −18,8% y el +82,8% sin
que el negocio haga nada. Por eso marketplace se lee en este report con media móvil
de tres meses y no punto a punto.

## 6. Lo que mira el CEO y lo que mira el Head of Wholesale

**No son el mismo gráfico, y ninguno de los dos es la tabla de este report.**

Para el **CEO**, cuatro números en una pantalla: 4,91 M€ de ingreso neto en el
último año, un +21,2% contra el año anterior, online poniendo el 58,7% de ese
crecimiento, y la mezcla de canales quieta. La conclusión que habilita es una sola:
el negocio crece de forma sana y equilibrada, y la palanca está en el canal que ya
es el más grande. Debajo, el aviso de comparabilidad, porque sin él este cuadro
lleva a la decisión equivocada sobre wholesale.

Para el **Head of Wholesale**, lo primero es que su canal no se compara con online.
Poner un canal B2B de 7.393 líneas al lado de uno B2C de 30.066 no le dice nada que
pueda usar. Lo suyo es su propio negocio: crece un 18,9%, es el único canal que
devuelve por debajo del 5% —una ventaja operativa enorme y real—, y su cuota de
ingreso neto es del 20,2%, cinco puntos por encima de lo que sugiere su
facturación. Y luego la conversación incómoda, que es justo la que aporta valor:
**en estos datos sus clientes compran al mismo precio que la web**. Si eso es un
fallo del dato, hay que arreglarlo antes de tomar ninguna decisión con este cuadro;
si fuera real, es la conversación de pricing más importante de la compañía.

Lo que ninguno de los dos puede pedirle a este dataset: el CEO querría margen por
canal, que está en la sección 03, y algo de recurrencia de cliente, que no existe
porque no hay identificador de cliente. El Head of Wholesale querría sell-through
por cuenta y cartera de pedidos, y no hay ni cuenta ni pedido.

---

## 7. Premisas, decisiones y límites de este report

Todo lo que hay debajo de los números. Está escrito aquí, y no en un anexo, porque
varias de estas decisiones cambian la lectura.

### Cómo se ha definido cada cosa

- **Ingreso neto = importe cobrado − impuestos − valor de lo devuelto.** Es el
  titular. El campo `net_sales` del dataset solo llega al segundo peldaño.
- **Se atribuye la devolución al mes de la venta**, no al mes en que se devolvió.
  Es la definición que un negocio necesita para cerrar un mes, y es la que este
  esquema hace imposible reproducir: la fila de la venta se sobrescribe cuando
  llega la devolución. La sección 02 va justamente de eso.
- **Grano mensual, comparando contra el mismo mes del año anterior.** Fechas
  convertidas a hora de Barcelona antes de agrupar; llegan en UTC.
- **Dos ventanas de 365 días** terminadas en la fecha de corte para medir
  crecimiento, en vez de años naturales, para comparar periodos del mismo tamaño.
- **El impuesto se quita a nivel global, nunca por país.** El dataset aplica un
  21% clavado en los ocho países, incluidos Estados Unidos y México, que no tienen
  ese impuesto. A nivel agregado la resta es correcta; por país no significaría
  nada.

### Lo que este dataset no permite responder

- **No hay identificador de cliente**, así que no hay recurrencia, ni clientes
  nuevos contra recurrentes, ni valor de vida.
- **No hay número de pedido.** El identificador de envío no sirve como sustituto:
  hay envíos que agrupan líneas separadas por dos años. Sin pedido no hay ticket
  medio ni prendas por cesta.
- **No hay destino observable.** El país vive en el envío, y el vínculo entre la
  venta y su envío es aleatorio, así que cualquier corte geográfico sería inventado.
- **No hay descuentos ni promociones** en dos años con dos Black Friday dentro. Es
  un dataset incompleto, no un dataset limpio.
- **No hay comisión de canal.** Marketplace se queda aquí el 100% de lo que
  factura, cuando en la realidad se lleva entre el 15% y el 20% menos.

### Los tres avisos que cambian cómo se lee la tabla

1. **El ranking mide impuesto y devolución, y nada más.** Los cuatro canales venden
   los mismos 200 artículos del catálogo, en la misma proporción de cada categoría,
   al mismo precio y con el mismo coste de producción. De los 22,1 puntos de margen
   que separan al canal más rentable del menos rentable, 12,3 son impuestos y 9,7
   son devoluciones; todo lo demás junto explica 0,19 puntos, menos que el error de
   medición.
2. **La cuota de wholesale está inflada.** Compra a precio de escaparate y no paga
   impuesto. Con precio de mayorista real, su ingreso sería menos de la mitad. La
   sección 03 publica ese escenario.
3. **Los meses de los extremos están incompletos.** Mayo de 2024 tiene tres días de
   ventas y mayo de 2026 le faltan dos: aparecen marcados y quedan fuera de las
   comparaciones. Al pasar las fechas a hora de Barcelona, los dos primeros días
   del dataset se quedan además fuera de las dos ventanas anuales; son 106 líneas,
   el 0,2%.

### Un descuadre que va a aparecer, y es a propósito

Este report cuenta **las 50.000 líneas**, incluidas 750 que venden artículos que no
existen en el catálogo. Son ventas reales y hay que facturarlas: aportan
143.169 € de ingreso neto. Pero no tienen ficha de producto y por tanto no tienen
coste, así que la sección 03 **las dejará fuera** del margen. Si alguien resta las
cifras de las dos secciones, la diferencia es esa y no un error.

### Sobre la calidad del dato

El dataset es sintético y tiene problemas plantados. Los once que encontramos están
documentados en [la auditoría](../hallazgos_auditoria.md), cada uno con su ejemplo
real y su consulta; las decisiones que salieron de ahí están en
[decisiones.md](../decisiones.md). Los que afectan a esta sección son los que acaban
de leerse; el resto pesa sobre la sección 03.

---

## 8. Lo que contestan las otras dos secciones

- **Sección 02 — Ingreso neto y devoluciones que llegan tarde.** Aquí hemos
  atribuido la devolución al mes de la venta. Esa definición es la correcta y es la
  que el esquema actual no puede sostener, porque la fila se sobrescribe. Ahí se
  propone el modelo que sí la sostiene.
- **Sección 03 — Margen de contribución.** Este report dice quién vende y quién
  crece. Quién gana dinero es otra pregunta, y la respuesta cambia el ranking otra
  vez: con precio de mayorista y comisión de marketplace puestos, el canal que aquí
  sube cinco puntos de cuota pasa a destruir valor.
