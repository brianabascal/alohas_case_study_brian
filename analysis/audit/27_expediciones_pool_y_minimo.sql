-- 27 · El transporte como pool y como numero de expediciones
--
-- Dos preguntas de negocio que DQ-04/DQ-09 dejaron abiertas:
--
--   1. Puente del dinero: cuanto porte hay en fct_shipment, cuanto llega a tocar
--      una linea de venta y cuanto se queda sin asignar. Es la reconciliacion que
--      un controller pediria antes de aceptar cualquier reparto.
--
--   2. Cota inferior fisica del numero de cajas: una expedicion no puede salir del
--      almacen en dos fechas, asi que el par (shipment_id, dia) es el minimo numero
--      de cajas compatible con los datos. Si ese minimo se acerca al numero de
--      lineas, entonces "1x por shipment_id" no es un caso base: es un suelo que
--      los propios datos descartan.

WITH linea AS (
  SELECT shipment_id, DATE(created_at) AS dia
  FROM `alohas-recruiting-study-case.production.fct_sale_order_line`
),

envio AS (
  SELECT shipment_id, shipping_cost
  FROM `alohas-recruiting-study-case.production.fct_shipment`
),

referenciado AS (
  SELECT DISTINCT shipment_id FROM linea
),

expedicion_minima AS (
  SELECT DISTINCT shipment_id, dia FROM linea
)

SELECT 'a. pool total en fct_shipment'            AS concepto,
       COUNT(*)                                   AS unidades,
       ROUND(SUM(shipping_cost), 2)               AS coste
FROM envio

UNION ALL
SELECT 'b. pool referenciado por alguna venta',
       COUNT(*), ROUND(SUM(e.shipping_cost), 2)
FROM envio e
JOIN referenciado r USING (shipment_id)

UNION ALL
SELECT 'c. pool huerfano (DQ-03)',
       COUNT(*), ROUND(SUM(e.shipping_cost), 2)
FROM envio e
LEFT JOIN referenciado r USING (shipment_id)
WHERE r.shipment_id IS NULL

UNION ALL
SELECT 'd. expediciones minimas (shipment x dia)',
       COUNT(*), ROUND(SUM(e.shipping_cost), 2)
FROM expedicion_minima x
JOIN envio e USING (shipment_id)

UNION ALL
SELECT 'e. cota alta: una expedicion por linea',
       COUNT(*), ROUND(SUM(e.shipping_cost), 2)
FROM linea l
JOIN envio e USING (shipment_id)

ORDER BY concepto
