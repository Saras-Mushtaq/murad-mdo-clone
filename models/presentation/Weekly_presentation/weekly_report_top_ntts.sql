-- with data as(
{{ config(
    materialized='table',
    partition_by={
      "field": "order_created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["Platform", "Sku", "sku_name"]
) }}
SELECT CAST(SKU AS STRING) Sku,sku_name,order_created_at,type,Platform,
SUM(Net_Revenue) AS Net_Revenue,
sum(CASE WHEN Net_Revenue != 0 THEN line_items_quantity ELSE 0 END) as Quantity from {{ ref('BCAndShopifyData') }} where
     Platform!='Tiktok'
 group by 1,2,3,4,5 
--  ),
-- base as(

-- select * from (select distinct sku,sku_name,type from data
-- where order_created_at >= '2022-01-01')

-- cross join
-- (SELECT 
-- date_value AS date
-- FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates
-- ),
-- base2 as(
--   select a.*,
--   coalesce(Net_Revenue,0) as Net_Revenue,
--   coalesce(Quantity,0) as Quantity
--   from base a
--   left join data b
--   on a.date = b.order_created_at and a.sku = b.sku and a.sku_name = b.sku_name and a.type=b.type
-- )
-- select a.*,coalesce(b.Net_Revenue,0) as LY_Revenue, coalesce(b.Quantity,0) as LY_Quantity
-- FROM base2 a
-- left join base2 b
-- on b.date = DATE_SUB(a.date, INTERVAL 52 week) and a.sku = b.sku AND a.sku_name=b.sku_name  and a.type=b.type
-- WHERE a.Net_Revenue+a.Quantity+b.Net_Revenue+b.Quantity!=0