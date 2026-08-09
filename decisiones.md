# Decisiones — Case study ALOHAS

Todo lo que hemos decidido y por qué. Cuando el dato no daba una respuesta, aquí
está escrito qué asumimos en su lugar y qué consecuencia tiene. De este fichero
sale directa la sección de asunciones del README.

Los **hechos medidos** viven en el otro documento,
[`hallazgos_auditoria.md`](hallazgos_auditoria.md). Aquí solo está la decisión
que se deriva de ellos, contada de forma que se entienda sin ir a buscarla.

---

## 0. El encargo, en cuatro líneas

ALOHAS es una marca de moda de Barcelona. Nos dan dos años de ventas en BigQuery
(`alohas-recruiting-study-case.production`) y tres preguntas para el CEO y el
hiring manager de datos:

1. **Ventas por canal.** ¿Cuál vende más y estamos comparando peras con peras?
2. **Ingreso neto y devoluciones que llegan tarde.** La fila de venta se
   sobrescribe cuando el cliente devuelve, así que el histórico se reescribe solo.
3. **Margen de contribución por canal**, incluyendo coste de producto, transporte
   y coste de la devolución.

Se entrega un repositorio público con el report en el navegador, el código y un
README. Nos valoran cinco cosas: cómo modelamos, cómo lo contamos, la calidad del
código, la comunicación y la conciencia de las limitaciones del dato. Hay bonus
por cazar problemas de calidad y por tratar el margen como una pregunta de
negocio y no como una fórmula.

---

## 1. Entorno y forma de trabajar

### [E-01] Acceso a BigQuery, solo lectura y con tres cierres

**Estado:** DECIDIDA (2026-08-04)

La cuenta personal de Brian tiene *Data Viewer* + *Job User* sobre el proyecto de
Alohas. Encima de eso, tres cierres: el rol es de solo lectura, las credenciales
locales piden únicamente el permiso de lectura de BigQuery, y hay un tope de 1 GiB
por consulta.

**Por qué tanto cuidado.** El riesgo no es romperles nada —no podemos, el permiso
no da para eso—. El riesgo es dejar credenciales amplias tiradas en un repo
público. Por eso no hay ni una credencial versionada.

La configuración del servidor MCP está en `.cursor/mcp.json`; el que usamos de
verdad es `scripts/bq.py`, un runner de 150 líneas contra la API REST.

### [E-02] Cada consulta exploratoria deja su rastro

**Estado:** DECIDIDA (2026-08-04)

Toda consulta acaba en `analysis/audit/NN_nombre.sql` y su resultado en
`analysis/audit/out/NN_nombre.csv`. El hallazgo que sale de ella se escribe en el
documento de hallazgos.

Las consultas se versionan; los CSV de salida no, de momento, porque son
resultados agregados de su dato y estamos esperando confirmación para publicarlos
(la misma pregunta que el extracto de D-02). Si dicen que sí, se quita esa línea
del `.gitignore` y la auditoría queda reproducible entera.

**Por qué.** El brief pide literalmente *"don't polish; let us see the working"*.
Esa carpeta **es** la prueba del bonus de calidad de dato: no decimos que
auditamos, se ve.

### [D-01] El modelado se hace con dbt

**Estado:** DECIDIDA (2026-08-03)

Capas staging / intermediate / marts. El brief menciona *"from the dbt layer to
the dashboards"*, así que es la herramienta que esperan ver.

### [D-02] El warehouse es local, no el proyecto de Alohas

**Estado:** DECIDIDA (2026-08-03, simplificada el 2026-08-08)

```
BigQuery (solo lectura) → CSV en el repo → dbt-duckdb → marts → report
```

Extraemos las tres tablas una vez a `data/raw/*.csv`, **esos CSV se versionan**, y
dbt los materializa en un DuckDB local que no se versiona.

**Por qué.** Con permiso de solo lectura no podemos crear tablas en su proyecto.
Y versionar el dato crudo tiene un premio: cualquiera clona el repo y ejecuta el
pipeline entero sin credenciales y sin acceso a Alohas. El entregable se vuelve
reproducible de verdad, no de boquilla.

**Lo que cuesta.** DuckDB no habla exactamente el mismo SQL que BigQuery. Se
escribe el SQL lo más estándar posible, los tipos se castean explícitamente al
leer los CSV, y en el README se explica que esto es consecuencia de los permisos y
no un descuido.

### [D-03] Presupuesto de tiempo: 12–15 horas

**Estado:** DECIDIDA (2026-08-03)

El brief recomienda 8. Las horas extra van a profundidad de análisis y a
redacción, no a añadir gráficos.

### [D-04] Formato del report

**Estado:** ABIERTA

Tres candidatos: Quarto a HTML con plotly, Evidence.dev, o un notebook exportado.
El brief prefiere HTML interactivo que se abra en el navegador.

---

## 2. Cómo tratamos el dato

### [D-05] El identificador de envío no sirve como identificador de pedido

**Estado:** DECIDIDA (2026-08-03, confirmada con datos el 2026-08-04)

No hay número de pedido en el dataset. La tentación era usar `shipment_id` como
sustituto: si varias líneas comparten envío, serían el mismo pedido. **No lo son.**

Un ejemplo basta: el envío `SHP-0010294` agrupa siete líneas, la primera del 29 de
mayo de 2024 y la última del 28 de mayo de 2026. Dos años entre la primera y la
última prenda de la misma "caja", y mezclando venta online, tienda física y
mayorista. Los cinco peores casos superan todos los 720 días.

**Consecuencia:** las métricas de pedido —ticket medio por pedido, prendas por
cesta, tasa de cesta múltiple— **quedan fuera de alcance** y se dice en el report.
No es que no nos dé tiempo: es que el dato no permite calcularlas.

El único papel que le queda a `shipment_id` es decidir qué envíos entran en el
pool de transporte (los que alguna venta menciona) y cuáles no.

### [D-06] El transporte es una factura que se reparte, no un coste de la venta

**Estado:** DECIDIDA (2026-08-03, reformulada el 2026-08-06, revisada el 2026-08-08)

**La situación.** Alohas se gastó 255.078 € en transporte en estos dos años. La
pregunta del margen es cuánto de esa factura consumió cada canal. La respuesta
obvia sería mirar a qué envío apunta cada venta y cobrarle su porte. No se puede,
porque ese vínculo está puesto al azar, y hay una forma de comprobarlo que no
admite discusión: si cada venta hubiera viajado en su propia caja —que es lo que
las fechas dicen, porque casi ninguna línea comparte envío *y* día con otra—, el
transporte habría costado 421.225 €. En la contabilidad de envíos solo hay
255.078 €. Faltarían dos de cada cinco euros.

**Lo que hacemos.** Tratar el transporte como lo que es, un gasto común que se
reparte de arriba abajo:

1. **El pool son 206.338,50 €**, que es el dinero de los envíos que alguna venta
   menciona.
2. Se reparte **a partes iguales entre las 50.000 líneas de venta: 4,13 € cada
   una**. Sobre una línea media de 255 €, eso es el 1,6% de lo que factura.
3. **Los 48.739,92 € restantes no se reparten.** Son 5.758 paquetes que ninguna
   venta menciona; no hay nadie a quien cobrárselos. La cifra se declara para que
   nadie confunda el total de la tabla de envíos con el gasto imputable, pero no
   toca ningún margen.

**La regla que no admite excepción.** El coste de transporte se calcula **siempre
recorriendo las líneas de venta**. Nunca sumando la tabla de envíos por su cuenta:
hacerlo mete esos 48.739,92 € huérfanos y te hace creer que gastas un 19% más de
lo que gastas. Es un error que no deja ni rastro en el dashboard, así que va
escrito como norma y no como recomendación.

**Por qué una tarifa plana y no repartir el porte real de cada paquete.** Porque
si el vínculo entre la venta y su envío es azar, entonces el método de envío que
la venta hereda por ese vínculo también es azar. Repartir el porte real conserva
esa variación falsa y la mete en el mart. La tarifa plana la tira, que es donde
tiene que estar.

Y hay un segundo motivo, más práctico: con tarifa plana **el análisis equivocado
deja de ser posible**. Si cada línea heredase el porte de su paquete, el día que
alguien haga "margen por método de envío" —el primer corte que se le ocurre a
cualquiera— saldría un gráfico espectacular y completamente falso. Así esa
pregunta no se puede ni formular.

**Lo que perdemos y dónde lo recuperamos.** Con tarifa plana no podemos decir nada
sobre la economía de cada método de envío. Eso se recupera en una tabla pequeña al
nivel del paquete, donde el método sí es un hecho: **el 10% de los paquetes (los
`next_day`) se lleva el 24% de la factura de transporte**. Es la única conclusión
logística accionable que soporta este dataset, y no necesita repartir nada.

**Que la elección no cambia las conclusiones está medido.** Repartiendo el porte
real dentro de cada envío, la tarifa por línea salía entre 4,11 € (online) y
4,17 € (marketplace). La tarifa plana se desvía como mucho un 1,1%, unos cuatro
céntimos sobre una línea de 255 €.

**Dos efectos colaterales, los dos a favor:**

- Las 500 líneas que apuntan a un envío que no existe dejan de ser un problema.
  Son ventas que evidentemente se enviaron; lo roto es el puntero, no el paquete.
  Con tarifa plana cargan sus 4,13 € como el resto.
- En el mart la columna **se llama `shipping_cost_allocated`, no `shipping_cost`**.
  La tarifa media por línea (4,13 €) y lo que cuesta un paquete de verdad (8,50 €
  de media) son cosas distintas, y alguien las va a confundir si se llaman igual.

**Consecuencia fuera del transporte.** Si el vínculo venta-envío es azar, el país
de destino también lo es, porque es un dato del envío. **Ninguna venta de este
dataset tiene destino observable**, así que cualquier corte geográfico queda fuera
del report o se marca como no interpretable.

**Lo que se probó antes y por qué se descartó:**

- *Repartir según las unidades vendidas.* El porte no crece con lo que va dentro
  del paquete: uno con una prenda costó 5,26 € y otro con ocho, 6,61 €. No hay
  base física para repartir por unidades.
- *Cobrar el porte una vez por envío.* El total cuadraba, pero descansaba sobre
  una agrupación que la propia auditoría había demostrado falsa.
- *Analizar solo los envíos de una línea.* Es el único subconjunto donde el
  vínculo no está desmentido, y es un espejo casi perfecto del total. Pero que una
  línea esté sola en su envío no demuestra que viajara sola, así que no compra
  verdad: cuesta el 81% de la facturación a cambio de nada. Se guarda como
  conjunto de control para validar que el margen del total no se desvía.

### [D-08] No hay fecha de devolución, así que la construimos con snapshots

**Estado:** DECIDIDA (2026-08-04)

Cuando un cliente devuelve, la fila de la venta original se actualiza. No queda
registro de cuándo pasó. Se asume que esa fecha **no está disponible aguas
arriba** y se diseña en consecuencia: un snapshot de la tabla que cambia, y la
devolución deducida comparando snapshots.

**Por qué no lo preguntamos.** Porque la respuesta no cambia el código. Si existe
aguas arriba, el snapshot es un puente hasta que la traigan; si no existe, el
snapshot es el destino. Se construye igual, y se anota el matiz en el report.

**Un matiz incómodo que hay que decir en voz alta.** En estos datos las
devoluciones ya están todas registradas: la tasa es plana (~14,8%) en los 25 meses,
y hasta el último mes vendido —a menos de un mes del corte— marca 15,2%. Si las
devoluciones tardaran 30–90 días como dice el brief, ese mes debería estar cerca de
cero. Conclusión: el sesgo del que nos avisan es real como riesgo futuro, pero en
este dataset **no se puede medir, hay que simularlo**. La curva de maduración de la
sección 02 es una asunción declarada, no una medición.

### [D-09] Las ventas sin ficha de producto salen del margen

**Estado:** DECIDIDA (2026-08-04)

750 líneas (203.240 €, el 1,6% de la facturación) venden artículos que no existen
en el catálogo. Se vende `SKU-90001`, pero el catálogo solo tiene códigos como
`SKU-01065`: los huérfanos viven todos en el rango `SKU-9xxxx`, otro espacio de
nombres, lo que apunta a una desincronización entre el maestro de producto y el
sistema de ventas.

Sin ficha no hay coste de producto, y sin coste no hay margen. Esas líneas salen
del mart de margen y **se publica cuánto dinero queda fuera**. No se pueden
rellenar imputando el coste medio de su categoría, porque tampoco tienen categoría.

### [D-10] El grano es la línea de pedido, con clave inventada

**Estado:** DECIDIDA (2026-08-04)

No hay clave primaria en la tabla de ventas: ni número de pedido, ni de línea. Se
construye una clave sintética y **se declara el grano en la documentación de cada
modelo: una fila = una línea de pedido**.

Sin clave natural hay una consecuencia que merece decirse: no se puede distinguir
una fila duplicada por error de dos líneas legítimamente idénticas. En este
dataset no hay duplicados exactos, así que no nos afecta, pero el hecho de que no
podríamos detectarlos sí es material para el report.

### [D-11] `UK` se normaliza a `GB` en staging

**Estado:** DECIDIDA (2026-08-04)

El Reino Unido aparece como `UK`; el código ISO es `GB`. No cambia ninguna cifra,
pero rompe cualquier cruce con tablas de países estándar. Se arregla en staging y
se menciona en una línea del README.

### [D-13] El IVA se quita a nivel global, nunca por país

**Estado:** DECIDIDA (2026-08-04)

El tipo efectivo es exactamente el 21,00% en los ocho países, **incluidos Estados
Unidos y México**. Una venta de 2.200 € con destino a México pagó 462 € de
impuesto, un 21% clavado. Estados Unidos no tiene IVA y México aplica el 16%.

Lectura: ese 21% es una constante aplicada en origen, no un impuesto de destino.
Y confirma que el precio de catálogo lleva el IVA dentro.

**Decisión:** para comparar canales se usa el ingreso sin IVA, que a nivel global
es correcto. Cualquier análisis fiscal por país queda fuera o se marca como
sesgado.

---

## 3. Cómo calculamos el margen

### [D-12] Todos los márgenes son un techo, y hay que decirlo

**Estado:** DECIDIDA (2026-08-04)

Tres cosas que declaramos en el report antes de enseñar ningún número:

1. **No hay ni un descuento en dos años.** El importe facturado es siempre el
   precio de catálogo por las unidades, sin una sola excepción en 50.000 filas,
   con dos Black Friday dentro. Eso no es un dataset limpio, es un dataset
   incompleto. Todo margen que salga de aquí es un **techo**.
2. **El mayorista compra a precio de escaparate.** El 100% de las líneas de
   wholesale están al mismo precio que la web, y además con impuesto cero. En la
   vida real un mayorista compra al 40–50% del precio de venta al público.
3. **El coste del catálogo es el de hoy aplicado a ventas de hace dos años.** La
   ficha de producto no tiene fechas de vigencia. Y como el precio nunca se mueve,
   tampoco podemos medir cuánto se ha desviado. Queda escrito como riesgo abierto.

### [D-14] Los costes que no están y no vamos a inventar

**Estado:** DECIDIDA (2026-08-04)

Comisiones de pago y coste de preparación de pedido (*pick & pack*) quedan **fuera
de alcance**: no están en el dato, no los preguntamos y no los estimamos. La
comisión de marketplace sí se modela, porque es la que de verdad mueve la
conclusión, y va en D-18.

### [D-18] El escenario: lo que el dataset no cobra y la realidad sí

**Estado:** DECIDIDA (2026-08-05, reformulada el 2026-08-08)

**El problema.** El dataset no permite diferenciar los canales por lo que de
verdad los diferencia en la vida real. Wholesale factura a precio de escaparate y
la comisión de marketplace no existe como campo. Sin corregir eso, el ranking de
rentabilidad es un artefacto: sale ganando quien no paga los peajes que en la
realidad sí paga.

**Cómo se resuelve, en dos capas separadas:**

1. **Capa reportada.** Lo que dice el dato, sin tocar. Cuadra con BigQuery al
   céntimo. Es el mart.
2. **Capa de escenario.** Dos parámetros que viven en un único sitio visible —una
   seed de dbt llamada `channel_economics`— y que producen **medidas nuevas**. No
   sobrescriben ni una columna de la capa reportada.

**Los dos números, que Alohas nos pidió explícitamente que modelásemos:**

- **Wholesale factura al 45% del precio de venta al público**, centro de la
  horquilla real del sector (40–50%).
- **Marketplace paga un 17,5% de comisión** sobre lo que cobra al cliente final,
  centro de la horquilla de Zalando y Amazon (15–20%).

**Y el resultado le da la vuelta a la mesa:**

| Canal | Margen reportado | Margen con el escenario | Contribución con el escenario |
|---|---|---|---|
| wholesale | 53,74% | **−2,80%** | −22.432 € |
| retail | 34,90% | 34,90% | 594.695 € |
| online | 31,60% | 31,60% | 1.552.609 € |
| marketplace | 34,48% | 12,33% | 53.740 € |

Wholesale pasa de ser el canal más rentable del dataset a **destruir valor**, y
marketplace se queda en un tercio del margen que aparentaba. Los dos canales que
no se mueven son los que Alohas controla de verdad, su tienda y su web, y ahí está
la lectura de negocio: **online, que en la foto sin corregir era el último del
ranking porcentual, es con diferencia el que más euros de contribución aporta —1,55
millones— y con el escenario puesto pasa a ser también el motor del negocio.**

**El matiz obligatorio al publicar esto.** El coste de producto en este dataset es
el 42,6% del precio de venta, un ratio altísimo para moda, donde lo normal es
20–30%. Así que el resultado adverso de wholesale viene tanto del precio que hemos
asumido como de un coste sintético inverosímil. Si no se dice, el escenario parece
un truco para que salga la conclusión bonita.

### [D-19] La prenda devuelta no vuelve a venderse

**Estado:** DECIDIDA (2026-08-05, cerrada como convención el 2026-08-08)

Cuando un cliente devuelve una prenda, ¿vuelve al almacén y se vende otra vez, o
se da de baja? Cambia el margen mucho, y el dato no lo dice.

**Convención: no se revende.** La venta pierde su ingreso y el coste de producción
se queda puesto.

**Por qué esta y no la contraria.** En moda la devolución llega fuera de
temporada, hay que reacondicionarla y rara vez se vuelve a colocar a precio
completo. Es la lectura prudente, y prudente es la que degrada bien: si mañana
Alohas dice que sí se revende, la conclusión mejora sin rehacer nada.

**Y hay que saber lo que esta convención decide, porque decide mucho.** La cesta
que se devuelve tiene el mismo ratio coste/precio que la que se vende (42,4%
contra 42,5%), así que si la prenda volviera a venderse, devolver restaría ingreso
y coste en la misma proporción y el margen porcentual ni se enteraría: los cuatro
canales quedarían empatados en el entorno del 43,7%. Con la convención de que no
se revende, la tasa de devolución **sí** separa, y separa 9,7 puntos entre online
(que devuelve el 17,9% de las prendas) y wholesale (que devuelve el 4,2%).

Dicho de otro modo: casi la mitad de la diferencia de rentabilidad que vamos a
publicar entre canales (9,7 de 22,1 puntos) existe **porque hemos asumido esto**.
Va declarado en el report al lado del número, no en una nota al pie.

### [D-21] Qué cuesta una devolución: tres convenciones, porque el dato no lo dice

**Estado:** DECIDIDA (2026-08-06, rehecha el 2026-08-08)

**El problema.** El brief exige meter el coste de una devolución en el margen de
contribución, y ese campo **no existe en el esquema**. No es que falte una
columna: falta la entidad entera. La devolución aquí es un contador pegado a la
línea de venta, sin fecha y sin paquete. El único candidato a rastro de logística
inversa eran los 5.758 envíos que ninguna venta menciona, y **Alohas confirmó que
no son devoluciones**.

Tampoco tienen una tarifa interna que darnos. Así que hay dos salidas malas
—inventarse una cifra plausible, o dejar el hueco a cero— y una intermedia, que es
la que tomamos: **decir en voz alta con qué convención trabajamos**.

**Las tres convenciones:**

1. **Traer la prenda de vuelta cuesta lo mismo que costó enviarla: 4,13 €**, la
   misma tarifa de transporte que carga la línea. Es la asunción más natural que
   se puede hacer sin dato: la devolución recorre el mismo camino al revés, con el
   mismo transportista.
2. **Como máximo una devolución por línea de pedido.** El coste se cobra **una vez
   por línea**, no por prenda. Importa: hay 973 líneas que devuelven entre dos y
   cuatro prendas, y contarlas por unidad multiplicaría el coste sin ninguna razón
   para creer que viajaron en paquetes separados.
3. **La prenda no se revende** (es D-19, y va aquí porque las tres se aplican
   juntas).

**Lo que sale:** 8.256 de las 50.000 líneas tienen devolución, así que la
logística inversa cuesta **34.071 € en dos años, el 0,27% de la facturación**.

**Lo que esta cifra deliberadamente no incluye,** y hay que escribirlo para que
nadie la lea como el coste real de devolver: no lleva el trabajo de recibir y
revisar la prenda en almacén, ni la atención al cliente, ni la pérdida de valor de
la prenda. Es **el suelo del coste de devolver**, no una estimación.

**Y es un parámetro, no una constante enterrada en el código.** Vive en la misma
seed que el resto de supuestos. Si Alohas encuentra su tarifa interna, se cambia
una celda y el margen se recalcula solo.

---

## 4. Cómo se presenta el report

### [D-15] Qué número llamamos "revenue"

**Estado:** DECIDIDA (2026-08-08)

**El problema, que además es la respuesta a la pregunta 01.** El dataset tiene un
campo llamado `net_sales` que **no es** neto de devoluciones: es la venta menos el
impuesto. El nombre engaña. Y como wholesale tiene impuesto cero, comparar canales
por ese campo es comparar un canal sin IVA contra otros tres con el IVA dentro. La
pregunta del brief es *"are we comparing like for like"* y la respuesta es que no,
y ese es justamente el hallazgo.

**La escalera que se usa en las tres secciones:**

```
importe facturado                       lo que se cobró, con IVA dentro
  − impuestos                           = ingreso sin IVA  (el "net_sales" del dataset)
  − valor de lo devuelto                = ingreso neto     ← el titular del report
  − coste de producto
  − transporte             4,13 € por línea
  − coste de devolución    4,13 € por línea con devolución
                                        = margen de contribución
```

Los dos últimos peldaños no son datos, son las convenciones de D-06 y D-21, y en
el report van etiquetados como tales.

**Se titula con el ingreso neto** (sin IVA y descontando lo devuelto), y la
escalera se enseña una sola vez al principio como gráfico de cascada. Eso resuelve
la comparabilidad entre canales, deja la definición escrita para todo lo que viene
después y responde a la pregunta 01 antes de que la hagan.

### [D-16] Defendemos la lectura "a fecha de la venta"

**Estado:** DECIDIDA (2026-08-08)

El brief pide elegir entre calcular el ingreso neto *as-of date of sale* o *as-of
report date*, y la frase es ambigua. Nuestra lectura: **las dos atribuyen la
devolución al mes de la venta; lo que cambia es con qué información se calcula.**

- *A fecha del report* es el mes de enero recalculado con todo lo que sabemos hoy.
  Es lo que sale por defecto con este esquema, y es un número **que se reescribe
  solo** cada vez que refrescas. Es la definición que empieza a mentir en
  silencio, que es literalmente el aviso del brief.
- *A fecha de la venta* es el mes de enero tal como se cerró cuando se cerró
  enero. Estable, auditable, y casa con lo que se presentó en su momento. Y **hoy
  es imposible de reproducir**, porque la fila se sobrescribe y no queda historia.

**Defendemos la segunda, y ese es el corazón de la sección 02:** la definición que
el negocio necesita para cerrar un mes es exactamente la que el esquema actual
hace imposible. Esa imposibilidad es la razón de negocio para snapshotear. No es
una preferencia de ingeniería.

**El corolario que hay que enseñar en un gráfico.** Como no hay fecha de
devolución, no se puede atribuir la devolución al periodo en que ocurre. Los meses
recientes siempre parecerán más sanos que los antiguos, porque sus devoluciones
todavía no han llegado. Cualquier serie de ingreso neto tiene un sesgo al alza en
la cola derecha, por construcción. El mismo mes visto con distintas madureces es
el gráfico que hay que enseñar.

### [D-17] El eje temporal: grano, zona horaria y madurez

**Estado:** DECIDIDA (2026-08-08)

**Grano.** El brief pregunta cuál es el grano temporal correcto, y la respuesta
buena no es uno sino **uno por audiencia**: mensual con comparativa contra el
mismo mes del año anterior para el CEO —comparar un mes con el anterior en moda es
ruido estacional puro—, y semanal para la curva de maduración de devoluciones.
Decirlo así ya es responder mejor que eligiendo uno.

**Zona horaria: `Europe/Madrid`.** Las fechas vienen en UTC y Alohas opera desde
Barcelona, que va una o dos horas por delante. Una venta a las 23:30 UTC del 31 de
octubre es del 1 de noviembre en Madrid. Afecta al cierre de cada mes y al
recuento de Black Friday, así que se convierte antes de agrupar y se dice en una
línea.

**Fecha de corte: 29 de mayo de 2026**, que en hora de Barcelona arrastra siete
líneas sueltas al día 30. Hace falta saberla para poder marcar qué meses están
inmaduros en devoluciones y para que las dos ventanas anuales de la sección 01
comparen periodos del mismo tamaño. Sin eso no se puede pintar honestamente ni un
gráfico de la sección 02.

### [D-20] La sección 01 declara que el canal es casi una etiqueta

**Estado:** DECIDIDA (2026-08-05, cifras actualizadas el 2026-08-08)

El ranking de canales se publica tal cual sale del dato, pero acompañado de la
explicación de por qué sale lo que sale. El párrafo a escribir:

> Los cuatro canales venden los mismos 200 artículos del catálogo, en la misma
> proporción de cada categoría, con el mismo importe medio por línea (unos 255 €),
> el mismo coste de producción por línea (unos 108,5 €) y la misma mezcla de
> métodos de envío. Solo difieren en dos cosas: si pagan IVA y cuánto devuelven.
> De los 22,1 puntos de margen que separan al canal más rentable del menos
> rentable, **12,3 son impuestos y 9,7 son devoluciones**; surtido, precio, coste
> y logística juntos explican 0,19 puntos, menos que el error de medición. Este
> ranking mide exactamente eso —quién paga IVA y quién devuelve— y no surtido,
> pricing, logística ni comisiones.

**Por qué.** Es lo contrario de lo que produce quien agrupa por canal y dibuja
barras. Cierra la pregunta antes de que el lector la haga y dice de dónde viene de
verdad la diferencia.

---

## 5. Lo que preguntamos a Alohas y lo que contestaron

### [D-07] El email: cuatro preguntas, cuatro respuestas

**Estado:** RESUELTA (enviado el 2026-08-04, ampliado el 2026-08-06, cerrado el
2026-08-08)

El criterio para decidir qué preguntar fue **preguntar hechos, no criterios**. Una
pregunta sobre cómo funciona el negocio es información que no podemos deducir y
que nos hace modelar mejor. Una pregunta que les pide tomar nuestra decisión de
modelado resta, porque el ejercicio consiste en tomarla y defenderla —el brief
avisa de que *"the assumptions matter as much as the answer"*.

| Pregunta | Respuesta | Qué salió de ahí |
|---|---|---|
| ¿Qué cuesta una devolución? ¿La prenda vuelve a stock? | No hay forma de calcularlo de verdad | Las tres convenciones de D-21 y D-19 |
| ¿Modelamos la comisión de marketplace o nos ceñimos al dataset? | Modelarla con asunciones explícitas y señalarlo | El 17,5% de D-18 |
| Wholesale a precio de escaparate, ¿simplificación o realidad? | Modelarlo con asunción explícita | El 45% del PVP de D-18 |
| Los 5.758 envíos sin línea de venta, ¿son devoluciones? | **No lo son** | Se descartó derivar de ahí el coste de devolución; ese dinero queda sin repartir (D-06) |

Se preguntó además si podíamos subir un extracto del dataset al repo público para
que el pipeline sea reproducible. El comportamiento por defecto, si no hay
respuesta, es subirlo: es dato sintético hecho para el ejercicio.

**Lo que deliberadamente no se preguntó.** Nada que se resolviera con una consulta
—preguntar algo que contesta un `COUNT(*)` es la peor señal posible—, nada ya
contestado en el brief, y sobre todo ninguna de las tres decisiones que **son** el
ejercicio: qué grano temporal usar, qué definición de ingreso neto defender y cómo
repartir el transporte. Tampoco se preguntó qué problemas de calidad habían
escondido: encontrarlos es el bonus.

---

## 6. Reglas al construir, para no tropezar

1. Nombres de tabla siempre completos: `alohas-recruiting-study-case.production.*`.
2. Las líneas con artículo fuera de catálogo (`SKU-9xxxx`) salen del mart de
   margen, y se cuantifica lo que queda fuera (~1,6% de la facturación).
3. **El transporte se calcula siempre recorriendo las líneas de venta, nunca
   sumando la tabla de envíos.** Tarifa plana de 4,13 € por línea. Los 48.739,92 €
   de envíos huérfanos quedan fuera.
4. En el mart la columna se llama `shipping_cost_allocated`, no `shipping_cost`.
   Si se llama como el campo de origen, el primero que filtre una línea creerá que
   enviarla costó eso.
5. El coste de devolución se carga **una vez por línea con devolución**, no por
   unidad devuelta.
6. El 21% de impuesto no se interpreta nunca como IVA real del país.
7. `UK` se normaliza a `GB` en staging.
8. Las fechas se pasan a `Europe/Madrid` antes de cerrar meses.
9. Los dos parámetros de escenario (`wholesale_price_realization = 0,45` y
   `marketplace_fee = 0,175`) viven en la seed `channel_economics` y **producen
   medidas nuevas**: nunca sobrescriben una columna reportada.
10. La curva de maduración de devoluciones de la sección 02 es **simulada**, no
    medida, y va etiquetada como tal en el propio gráfico.
11. Toda consulta exploratoria nueva deja su `.sql` en `analysis/audit/` y su CSV
    en `analysis/audit/out/`.

---

## 7. Lo que haría con más tiempo

Va en el README, y es tan parte del entregable como el análisis. No son excusas:
son las cosas que sé que faltan.

- **Calcular a partir de qué comisión o de qué precio de mayorista cada canal deja
  de ser rentable.** Hoy publicamos un escenario con dos números elegidos del
  centro de la horquilla del sector; lo elegante sería publicar el filo, para que
  el lector ponga su propio número y vea si la conclusión aguanta.
- **Calendario retail 4-5-4.** El retail de moda lo usa para que las semanas casen
  año contra año. Con calendario natural, Black Friday puede caer en semanas
  distintas y la comparativa de noviembre miente.
- **Sensibilidad a la convención de la devolución.** Enseñar cuánto se mueve el
  ranking si la prenda devuelta sí se revende, o si traerla cuesta el doble.
- **Un test de calidad continuo** que avise si vuelven a aparecer artículos fuera
  de catálogo o envíos sin venta, en vez de haberlo encontrado a mano una vez.

---

## 8. Índice

| ID | Decisión | Estado |
|---|---|---|
| E-01 | BigQuery de solo lectura, sin credenciales en el repo | DECIDIDA |
| E-02 | Cada consulta deja su `.sql` y su CSV | DECIDIDA |
| D-01 | El modelado se hace con dbt | DECIDIDA |
| D-02 | CSV versionados y warehouse local con DuckDB | DECIDIDA |
| D-03 | 12–15 horas de presupuesto | DECIDIDA |
| D-04 | Formato del report | **ABIERTA** |
| D-05 | El envío no sirve como pedido; métricas de pedido fuera | DECIDIDA |
| D-06 | Transporte = pool repartido a 4,13 €/línea; huérfanos fuera | DECIDIDA |
| D-08 | Sin fecha de devolución: snapshots, y maduración simulada | DECIDIDA |
| D-09 | Ventas sin ficha de producto fuera del margen | DECIDIDA |
| D-10 | Grano = línea de pedido, con clave sintética | DECIDIDA |
| D-11 | `UK` se normaliza a `GB` | DECIDIDA |
| D-12 | Todos los márgenes son un techo | DECIDIDA |
| D-13 | El IVA se quita a nivel global, nunca por país | DECIDIDA |
| D-14 | Comisiones de pago y pick&pack fuera de alcance | DECIDIDA |
| D-15 | El titular es el ingreso neto; escalera en cascada | DECIDIDA |
| D-16 | Se defiende la lectura "a fecha de la venta" | DECIDIDA |
| D-17 | Grano por audiencia, `Europe/Madrid`, corte 2026-05-29 | DECIDIDA |
| D-18 | Escenario: wholesale al 45% del PVP, marketplace al 17,5% | DECIDIDA |
| D-19 | La prenda devuelta no se revende | DECIDIDA |
| D-21 | La devolución cuesta lo mismo que el envío, una vez por línea | DECIDIDA |
| D-20 | La sección 01 declara que el canal es casi una etiqueta | DECIDIDA |
| D-07 | El email: cuatro preguntas, todas contestadas | RESUELTA |

---

## Referencias

- Hechos medidos: [`hallazgos_auditoria.md`](hallazgos_auditoria.md)
- Consultas de la auditoría: `analysis/audit/`, resultados en `analysis/audit/out/`
- Material de preparación ya superado: [`archivo/`](archivo/LEEME.md)
