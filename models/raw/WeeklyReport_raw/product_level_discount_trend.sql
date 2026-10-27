{{ config(
    materialized='table',
    partition_by={
      "field": "created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "sku","name", "order_id", 'email']
) }}


with
excess_sku as(
   SELECT 
    sku,
    COALESCE(date(start_date),DATE(Start_Date_dt)) start_date,
    COALESCE(date(end_date),DATE(End_Date_dt)) end_date
FROM murad-data-warehouse.BigQuery.Murad_US_Excess_Excess_Promo_BQ_Excess_Promo,
UNNEST(
  ARRAY(
    SELECT TRIM(sku) sku
    FROM UNNEST(SPLIT(REPLACE(skus, "'", ""), ",")) AS sku
  )
) sku
),
orders as(
SELECT
  DATE(TIMESTAMP(created_at), "America/Los_Angeles") created_at,
  SAFE_CAST(a.id AS STRING) AS order_id,email,
  case when SAFE_CAST(discount_app.TYPE AS STRING)='automatic' and discount_app.target_type!='line_item' then null else
  SAFE_CAST(discount_app.TYPE AS STRING) end AS discount_applications_TYPE,
  case when lower(safe_cast(discount_app.code as string)) like '%wsms%' then 'WELCOMESMS' else safe_cast(discount_app.code as string) end as discount_applications_code,
--   SAFE_CAST(discount_app.code AS STRING) AS discount_applications_code,
  l.sku,
  l.title name,
  cast(l.quantity as float64) quantity,
    case 
    when SAFE_CAST(a.id AS STRING) in (select distinct order_id from {{ref("Shopify_US_OrderLines")}} where lower(source_name) like '%tiktok%') then 'Tiktok' 
    when concat(SAFE_CAST(a.id AS STRING),sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%recurring%') then 'Recurring'
    when concat(SAFE_CAST(a.id AS STRING),sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%first%order%') then 
( Case when concat(SAFE_CAST(a.id AS STRING),sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID
  
            ) where row_num = 1 and line_items_purchase_item_type='subscription') then 'Checkout-Recurring' else 'Checkout-OTP' END

)
else 'OTP' end Platform,
  cast(l.price as float64) price,
  cast(d.amount as float64) discount,
  -- safe_cast(discount_app.target_type as string) as discount_applications_target_type,
  d.discount_application_index,
  round(( COALESCE(CAST(l.quantity AS FLOAT64), 0) * COALESCE(CAST(l.price AS FLOAT64), 0)) - COALESCE(CAST(d.amount AS FLOAT64), 0),1) AS net_revenue

FROM murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
LEFT JOIN UNNEST(a.discount_applications) AS discount_app WITH OFFSET AS discount_offset ON TRUE
LEFT JOIN UNNEST(a.line_items) AS l
LEFT JOIN UNNEST(l.discount_allocations) AS d
WHERE discount_offset=d.discount_application_index and  date(created_at)>'2024-02-29' and 
   a.id in (select distinct cast(order_id as numeric) from {{ref("Shopify_US_OrderLines")}} where lower(source_name) like '%web%') and cast(l.price as float64)!=0
QUALIFY DENSE_RANK() OVER (PARTITION BY a.id ORDER BY _daton_batch_runtime DESC) = 1

union all

SELECT
  DATE(TIMESTAMP(created_at), "America/Los_Angeles") created_at,
  SAFE_CAST(a.id AS STRING) AS order_id,email,
  CAST(NULL AS STRING) AS discount_applications_TYPE,
  CAST(NULL AS STRING) AS discount_applications_code,
  l.sku,
  l.title name,
  cast(l.quantity as float64) quantity,
    case 
    when SAFE_CAST(a.id AS STRING) in (select distinct order_id from {{ref("Shopify_US_OrderLines")}} where lower(source_name) like '%tiktok%') then 'Tiktok' 
    when concat(SAFE_CAST(a.id AS STRING),sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%recurring%') then 'Recurring'
    when concat(SAFE_CAST(a.id AS STRING),sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%first%order%') then 
( Case when concat(SAFE_CAST(a.id AS STRING),sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID
  
            ) where row_num = 1 and line_items_purchase_item_type='subscription') then 'Checkout-Recurring' else 'Checkout-OTP' END

)
else 'OTP' end Platform,
  cast(l.price as float64) price,
  cast(d.amount as float64) discount,
  -- safe_cast(discount_app.target_type as string) as discount_applications_target_type,
  d.discount_application_index,
  ( COALESCE(CAST(l.quantity AS FLOAT64), 0) * COALESCE(CAST(l.price AS FLOAT64), 0)) - COALESCE(CAST(d.amount AS FLOAT64), 0) AS net_revenue
FROM murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
LEFT JOIN UNNEST(a.line_items) AS l
LEFT JOIN UNNEST(l.discount_allocations) AS d
WHERE d.discount_application_index IS NULL and  date(created_at)>'2024-02-29' and 
   a.id in (select distinct cast(order_id as numeric) from {{ref("Shopify_US_OrderLines")}} where lower(source_name) like '%web%')  and cast(l.price as float64)!=0
QUALIFY DENSE_RANK() OVER (PARTITION BY a.id ORDER BY _daton_batch_runtime DESC) = 1
),
SF as(
select a.* except(discount_application_index),
case 
WHEN a.sku in (
      SELECT distinct es.sku 
      FROM excess_sku es
      WHERE es.sku = a.sku
        AND DATE(a.created_at) BETWEEN es.start_date AND es.end_date
    ) THEN 'Promo - Excess'
when lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes )
or (lower(discount_applications_type)='manual' and Platform!='Checkout-Recurring')
then 'Promo - Discount'
WHEN discount_applications_TYPE='automatic' THEN 'Promo - Automatic'
--checkout
when platform='Checkout-Recurring' then 'Promo - Checkout'
when
lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main) or lower(trim(discount_applications_code))='welcomesms'
then 'Core - DM'
when lower(trim(discount_applications_code)) is null then 'Core - No-promo'
else 'Core - Loyalty' end type
 from orders a  
),list_price as(
  select created_at,order_id,base.sku,base.name,max(cast(ff.price as numeric)) list_price from SF base left join 
(select * from {{ref("CompareAtPrice")}} where cast(price as numeric) != 0)ff on 
lower(trim(base.sku))=lower(trim(ff.sku)) and lower(trim(base.name))=lower(trim(ff.sku_name)) and
 base.created_at>=date(ff.start_date) and base.created_at<date(ff.end_date) 
 group by 1,2,3,4
)
select *, 
case when type='Promo - Excess' then type
when type='Promo - Discount' then type
when discount_applications_TYPE='automatic' and  order_id
in(select distinct cast(a.id as string)
FROM murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
LEFT JOIN UNNEST(a.discount_applications) AS discount_app WITH OFFSET AS discount_offset ON TRUE
LEFT JOIN UNNEST(a.line_items) AS l
LEFT JOIN UNNEST(l.properties) AS p
LEFT JOIN UNNEST(l.discount_allocations) AS d
where lower(tags) like '%infomercial%' 
and lower(p.value) like '%free gift%' )
then 'Promo - Infomercial'
when type='Promo - Automatic' then type
When type='Promo - Checkout' Then type
when price<list_price and  order_id 
in(select distinct order_id from  {{ref("Shopify_US_OrderLines")}} where lower(tags) like '%infomercial%' )  then 'Promo - Infomercial'

when price<list_price then 'Promo - Strike-Through'
else type end as granular_type,
'Product' as representation_type

from(
select BASE.*,
coalesce(cast(list_price as numeric),price) list_price,
coalesce(cast(list_price as numeric),price) * Quantity total_MSRP,
from SF base 
left join 
list_price ff on 
  base.order_id=ff.order_id and
lower(trim(base.sku))=lower(trim(ff.sku)) and lower(trim(base.name))=lower(trim(ff.name))) 
-- where order_id='6411230576943'