{{ config(
    materialized='table',
    partition_by={
      "field": "SKU",
      "data_type": "String"
    },
    cluster_by=[ "sku_name"]
) }}

WITH price_changes AS (
  SELECT
    sku1 SKU,
    name1 SKU_NAME,
    PRICE,
    DATE(date) AS day,
    CASE 
      WHEN PRICE = LAG(PRICE) OVER (PARTITION BY SKU1, name1 ORDER BY DATE(date)) 
      THEN 0 ELSE 1 
    END AS is_new_period
  FROM murad-data-warehouse.BigQuery.Compare_at_price

--   SELECT
--     SKU1 SKU,
--     NAME1 SKU_NAME,
--     PRICE,
--     DATE(DATE) AS day,
--     CASE 
--       WHEN PRICE = LAG(PRICE) OVER (PARTITION BY SKU1, NAME1 ORDER BY DATE(DATE)) 
--       THEN 0 ELSE 1 
--     END AS is_new_period
--   FROM murad-data-warehouse.BigQuery.Compare_at_price

),
-- WITH price_changes AS (
--   SELECT
--     SKU,
--     SKU_NAME,
--     PRICE,
--     DATE(day) AS day,
--     CASE 
--       WHEN PRICE = LAG(PRICE) OVER (PARTITION BY SKU, SKU_NAME ORDER BY DATE(day)) 
--       THEN 0 ELSE 1 
--     END AS is_new_period
--   FROM `BigQuery.CompareAtPrice`
-- ),
-- grouped AS (
--   SELECT
--     SKU,
--     SKU_NAME,
--     PRICE,
--     day,
--     SUM(is_new_period) OVER (
--       PARTITION BY SKU, SKU_NAME ORDER BY day ROWS UNBOUNDED PRECEDING
--     ) AS grp
--   FROM price_changes
-- ),
-- periods AS (
--   SELECT
--     SKU,
--     SKU_NAME,
--     PRICE,
--     MIN(day) AS start_date,
--     MAX(day) AS end_date,
--     grp
--   FROM grouped
--   GROUP BY SKU, SKU_NAME, PRICE, grp
-- ),
-- deduped AS (
--   SELECT
--     SKU,
--     SKU_NAME,
--     MAX(PRICE) AS PRICE,
--     start_date,
--     end_date
--   FROM periods
--   GROUP BY SKU, SKU_NAME, start_date, end_date
-- ),
-- numbered AS (
--   SELECT
--     d.*,
--     ROW_NUMBER() OVER (PARTITION BY SKU, SKU_NAME ORDER BY start_date ASC) AS rn_asc,
--     ROW_NUMBER() OVER (PARTITION BY SKU, SKU_NAME ORDER BY start_date DESC) AS rn_desc
--   FROM deduped d
-- ),
-- adjusted AS (
--   SELECT
--     SKU,
--     SKU_NAME,
--     PRICE,
--     COALESCE(LAG(end_date) OVER (PARTITION BY SKU, SKU_NAME ORDER BY start_date), start_date) AS start_date,
--     end_date
--   FROM numbered
-- )
-- SELECT
--   SKU,
--   SKU_NAME,
--   PRICE,
--   start_date,
--   end_date
-- FROM adjusted
-- ORDER BY start_date
-- WITH price_changes AS (
--   SELECT
--     SKU,
--     SKU_NAME,
--     PRICE,
--     DATE(day) AS day,
--     CASE 
--       WHEN PRICE = LAG(PRICE) OVER (PARTITION BY SKU, SKU_NAME ORDER BY DATE(day)) 
--       THEN 0 ELSE 1 
--     END AS is_new_period
--   FROM `BigQuery.CompareAtPrice`
-- ),
grouped AS (
  SELECT
    SKU,
    SKU_NAME,
    PRICE,
    day,
    SUM(is_new_period) OVER (
      PARTITION BY SKU, SKU_NAME ORDER BY day ROWS UNBOUNDED PRECEDING
    ) AS grp
  FROM price_changes
),
periods AS (
  SELECT
    SKU,
    SKU_NAME,
    PRICE,
    MIN(day) AS start_date,
    MAX(day) AS end_date,
    grp
  FROM grouped
  GROUP BY SKU, SKU_NAME, PRICE, grp),
deduped AS (
  SELECT
    SKU,
    SKU_NAME,
    MAX(PRICE) AS PRICE,
    start_date,
    end_date
  FROM periods
  GROUP BY SKU, SKU_NAME, start_date, end_date),
final as(
    select * from deduped where start_date!=end_date )
,final_f as (
    SELECT
    SKU,
    SKU_NAME,
    PRICE,
    LAG(end_date) OVER (PARTITION BY SKU, SKU_NAME ORDER BY start_date) AS start_date,
    end_date
  FROM final ),
numbered AS (
  SELECT
    d.*,
    ROW_NUMBER() OVER (PARTITION BY SKU, SKU_NAME ORDER BY start_date ASC) AS rn_asc,
    ROW_NUMBER() OVER (PARTITION BY SKU, SKU_NAME ORDER BY start_date DESC) AS rn_desc
  FROM final_f d 
)
select sku,sku_name,price,case when rn_asc=1 then '2024-01-01' else start_date end as start_date,case when rn_desc=1 then current_date() else end_date end as end_date from numbered