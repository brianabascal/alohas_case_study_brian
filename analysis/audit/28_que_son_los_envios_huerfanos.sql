-- 28 · ¿Se puede darle un nombre a los 5.758 envios huerfanos?
--
-- En una empresa de moda real, un paquete sin linea de venta tiene nombre:
-- devolucion entrante, cambio, reposicion, muestra a prensa, traspaso a tienda.
-- Cada uno de esos nombres deja una huella distinta en el metodo y en el pais.
--
-- Resultado: no hay huella. El mix de metodo y de pais de los huerfanos es
-- indistinguible del de los envios con venta, y su coste medio por paquete es el
-- mismo (8,46 EUR). Los datos no permiten clasificarlos, asi que el pool se
-- declara y se deja fuera del reparto (DQ-03). Alohas confirma ademas que no son
-- devoluciones (2026-08-08), asi que por aqui tampoco sale el coste de un retorno.

WITH linea AS (
  SELECT shipment_id, quantity_sold, quantity_returned
  FROM `alohas-recruiting-study-case.production.fct_sale_order_line`
),

envio AS (
  SELECT shipment_id, shipping_method, country, shipping_cost
  FROM `alohas-recruiting-study-case.production.fct_shipment`
),

referenciado AS (
  SELECT DISTINCT shipment_id FROM linea
),

clasificado AS (
  SELECT e.*, r.shipment_id IS NULL AS es_huerfano
  FROM envio e
  LEFT JOIN referenciado r USING (shipment_id)
)

SELECT 'metodo' AS eje,
       shipping_method AS valor,
       COUNTIF(es_huerfano) AS huerfanos,
       ROUND(100 * COUNTIF(es_huerfano) / SUM(COUNTIF(es_huerfano)) OVER (), 2) AS pct_huerfanos,
       COUNTIF(NOT es_huerfano) AS con_venta,
       ROUND(100 * COUNTIF(NOT es_huerfano) / SUM(COUNTIF(NOT es_huerfano)) OVER (), 2) AS pct_con_venta
FROM clasificado
GROUP BY 1, 2

UNION ALL
SELECT 'pais', country,
       COUNTIF(es_huerfano),
       ROUND(100 * COUNTIF(es_huerfano) / SUM(COUNTIF(es_huerfano)) OVER (), 2),
       COUNTIF(NOT es_huerfano),
       ROUND(100 * COUNTIF(NOT es_huerfano) / SUM(COUNTIF(NOT es_huerfano)) OVER (), 2)
FROM clasificado
GROUP BY 1, 2

UNION ALL
SELECT 'unidades', 'vendidas / devueltas',
       (SELECT SUM(quantity_returned) FROM linea), NULL,
       (SELECT SUM(quantity_sold) FROM linea), NULL

ORDER BY eje, valor
