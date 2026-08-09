-- 01 · Inventario del dataset: que tablas hay, con que columnas y de que tipo.
-- Objetivo: contrastar el schema real contra el que describe el brief, y en
-- particular buscar columnas no documentadas que puedan ser clave natural
-- (valida o refuta [A-01]).

select
    t.table_name,
    t.table_type,
    c.ordinal_position,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.is_partitioning_column
from `alohas-recruiting-study-case.production.INFORMATION_SCHEMA.TABLES` as t
join `alohas-recruiting-study-case.production.INFORMATION_SCHEMA.COLUMNS` as c
    using (table_catalog, table_schema, table_name)
order by t.table_name, c.ordinal_position
