{{ config(
    materialized='table',
    partition_by={
      "field": "created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "New_Bucket", "order_id"]
) }}

with excess_sku as(
   SELECT 
    sku,
    coalesce(date(start_date),date(Start_Date_dt)) start_date,
    coalesce(date(end_date),date(End_Date_dt)) end_date
FROM murad-data-warehouse.BigQuery.Murad_US_Excess_Excess_Promo_BQ_Excess_Promo,
UNNEST(
  ARRAY(
    SELECT TRIM(sku) sku
    FROM UNNEST(SPLIT(REPLACE(skus, "'", ""), ",")) AS sku
  )
) sku
),
base2 as(
SELECT
case
  when order_id in (select distinct order_id from {{ref("Shopify_US_OrderLines")}}
where lower(source_name) like '%tiktok%') then 'Tiktok'
when concat(order_id,line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%recurring%')  then 'Recurring Subscription'
  else 'Non-Tiktok'
  end platform,
  DATE(created_at) created_at,
  order_id,
  email,
  oi.discount_applications_code_line_item c_code,
  -- case when lower(trim(oi.discount_applications_code_line_item)) is null then 'N' else 'Y' end code_string,
  oi.line_items_sku AS sku,
  oi.line_items_title AS sku_name,GWP_Product,
  CASE 
    WHEN oi.line_items_sku in (
      SELECT distinct es.sku 
      FROM excess_sku es
      WHERE es.sku = oi.line_items_sku
        AND DATE(oi.created_at) BETWEEN es.start_date AND es.end_date
    ) THEN 'excess'
    ELSE NULL
  END AS excess,
  coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
  coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
  coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
  coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
  sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - SUM(coalesce(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue
FROM
  {{ref("Shopify_US_OrderLines")}} oi
    where date(created_at) >= '2024-02-29'
    group by 1,2,3,4,5,6,7,8,9
),
Automatic_promos as
(
  select concat(order_id,sku,lower(sku_name)) match_string from(select distinct safe_cast(a.id as string) as order_id,
safe_cast(li.sku as string) as sku,
lower(safe_cast(li.title as string)) as sku_name,
from murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
left join unnest(discount_applications) discount_applications
left join unnest(line_items) li
where 'line_item' = safe_cast(discount_applications.target_type as string) and 'automatic' = safe_cast(discount_applications.type as string)
qualify dense_rank() over (partition by a.id,li.sku,li.title order by _daton_batch_runtime desc) = 1
)),
New_Promo_Orders as
(
  with base as
(select
safe_cast(a.id as string) as order_id,
safe_cast(discount_applications.target_type as string) as discount_applications_target_type,
case when lower(safe_cast(discount_applications.code as string)) like '%wsms%' then 'WELCOME15SMS' else safe_cast(discount_applications.code as string) end as discount_applications_code,
-- safe_cast(discount_applications.code as string) as discount_applications_code,
from murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
left join unnest(discount_applications) discount_applications
qualify dense_rank() over (partition by a.id order by _daton_batch_runtime desc) = 1
)
,actual_code as(
select
distinct order_id, discount_applications_code,
case when
lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(discount_applications_code)) in (select distinct lower(code) from `murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes`)
then 'Promo'
else 'Loyalty' end type,
case when
lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(discount_applications_code)) in (select distinct lower(code) from `murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes`)
then upper(trim(discount_applications_code)) else null end as Promo_type
from base
where lower(trim(discount_applications_target_type)) = 'line_item' and discount_applications_code is not null
)
select distinct type,order_id promo_order_id,promo_type from actual_code
where type = 'Promo'
union all
select distinct type,order_id promo_order_id,promo_type from actual_code
where order_id not in
(
  select distinct order_id from actual_code
where type = 'Promo'
)
),
-- GWP_Base as
-- (
--         SELECT
-- distinct v.sku GWP_SKU,
-- min(date(a.updated_at)) GWP_min_date,max(date(a.updated_at)) GWP_max_date
-- -- distinct id
-- FROM `murad-data-warehouse.BigQuery.Murad_US_Shopify_products` a
-- left join unnest(a.variants) v
-- where
-- lower(tags) like '%gwp%' and date(a.updated_at) >= '2024-02-29'
-- group by 1
-- order by 3 desc
-- ),
-- New_GWP_Base as
-- (
--  with base as(SELECT
-- distinct
-- v.sku sku,
-- lower(tags) tags,
-- date(a.updated_at) date,
-- FROM `murad-data-warehouse.BigQuery.Murad_US_Shopify_products` a
-- left join unnest(a.variants) v
-- where
-- date(a.updated_at) >= '2024-02-29'
-- and
-- (lower(tags) like '%promo gwp%'
-- )
-- order by 1,3)
-- ,base2 as(
-- select
-- *,sum(counter) over(partition by sku,tags rows between unbounded preceding and current row) Group_Id
-- from(
-- select
-- *,
-- if(lag(date) over(partition by sku,tags order by date)= date-1,0,1) counter
-- from base
-- ))
-- select
-- sku gwp_sku,
-- tags,
-- Group_ID,
-- 'GWP' as type2,
-- min(date) min_date, max(date) max_date
-- from base2
-- group by 1,2,3,4
-- order by 1,2,3
-- ),
ultimate_base as(
select base2.*,promo_type,
case
when type = 'Promo' then 'Promo'
-- when type is not null then type
when platform = 'Tiktok' then 'Tiktok'
when platform = 'Recurring Subscription'  then 'Recurring Subscription'
WHEN excess='excess' then 'Excess Promo'
when concat(order_id,sku,lower(sku_name)) in (select distinct match_string from Automatic_promos) then 'Automatic Promo'
when type = 'Loyalty' then 'Loyalty'
when GWP_Product = True then 'GWP'
end type, sum(net_revenue) over(partition by created_at,sku,sku_name,ORDER_ID) check_GWP
from base2
left join New_Promo_Orders
on order_id = promo_order_id

)
-- select c_code,
-- count(distinct order_id)
-- from ultimate_base
-- where type = 'Loyalty'
-- group by 1
-- order by 2 desc
,pivot_base as(
select
created_at,
final_type New_Bucket,order_id,sku,promo_type,
sum(net_revenue) net_revenue
from
(
select *,
case
when type in ('Promo','Loyalty','Excess Promo','Automatic Promo','Recurring Subscription','Tiktok') then type
when order_id in (select distinct order_id from ultimate_base where type = 'GWP' and check_GWP = 0) then 'GWP' 
else 'No-Promo' end final_type
from ultimate_base
)
group by 1,2,3,4,5
order by 1,2),
all_combinations as (
  select d.created_at, p.New_Bucket
  from (select distinct created_at from pivot_base) d
  cross join (select distinct New_Bucket from pivot_base) p
)
select * from pivot_base 