{{ config(
    materialized='table',
    partition_by={
      "field": "DATE",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["code"]
) }}

WITH
BC AS
(
   SELECT
   DATE(date_created) AS date,
   CAST(id AS STRING) AS order_id,
   trim(lower(sa_email)) as email,
   case when
lower(trim(c_code)) in (select distinct lower(trim(code)) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(c_code)) in (select distinct lower(code) from `murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes` where type = 'Non Recharge')
then lower(trim(c_code))
else null
end code,
   p_sku as SKU,
   p_name as SKU_Name,
   p_quantity as line_items_quantity,
   case when lower(m_namespace) like '%recharge%' then 'Subscription' else 'Otp' end Platform,
   SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) line_items_price,
   avg(cast(refunded_amount as numeric)) line_items_refund,
   sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) line_item_discount,
   SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) - sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) - sum(cast(p_refund_amount as numeric)) Net_Revenue
   FROM {{ref("BC_US_Orders" ) }} 
   WHERE LOWER(status) IN ('awaiting fulfillment','awaiting shipment','awaiting pickup','completed','shipped','partially shipped','partially refunded')
   group by 1,2,3,4,5,6,7,8
),
SF AS
(
 with SF1 AS
 (SELECT
 DATE(created_at) date,
 order_id,
 trim(lower(email)) email,
 COALESCE(oi.discount_applications_code_line_item,oi.discount_applications_code_shipping_line) code,
 oi.line_items_sku AS sku,
 oi.line_items_title AS sku_name,
 coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
 case
 when order_id in (select distinct order_id from {{ref("Shopify_US_OrderLines")}}
where lower(source_name) like '%tiktok%') then 'Tiktok'
 when concat(order_id,line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%')  then 'Subscription'
 else 'Otp'
 end platform,
 coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
 coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
 coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
 sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - SUM(coalesce(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue
FROM
 {{ref("Shopify_US_OrderLines")}}  oi
 where date(created_at) >= '2024-02-29'
 group by 1,2,3,4,5,6
)
-- refunds as(
--  select * from SF1
--  where line_items_qty < 0
-- )
select a.date,a.order_id,a.email,a.code, a.sku,a.sku_name,coalesce(a.line_items_qty,0) line_items_qty,a.platform,a.line_items_price,a.line_items_refund,a.line_item_discount, coalesce(a.net_revenue,0) net_revenue
from (select * from SF1 ) a
-- left join refunds b
-- on a.order_id = b.order_id and a.sku = b.sku and a.sku_name = b.sku_name
),
actual_code as
(
with base as
(select
safe_cast(a.id as string) as order_id,
safe_cast(discount_applications.target_type as string) as discount_applications_target_type,
case when lower(safe_cast(discount_applications.code as string)) like '%wsms%' then 'WELCOMESMS' else safe_cast(discount_applications.code as string) end as discount_applications_code,
from murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
left join unnest(discount_applications) discount_applications
qualify dense_rank() over (partition by a.id order by _daton_batch_runtime desc) = 1
)
,pre_actual_code as(
select
distinct order_id, discount_applications_code,
case when
lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(discount_applications_code)) in (select distinct lower(code) from `murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes` ) or lower(trim(discount_applications_code))='welcomesms'
then 'Promo'
else 'Loyalty' end type
from base
where lower(trim(discount_applications_target_type)) = 'line_item' and discount_applications_code is not null
)
select
distinct order_id promo_order_id, discount_applications_code
from pre_actual_code
where (lower(discount_applications_code) like '%bf2024%' or lower(discount_applications_code) like '%cyber2024%')
union all
select distinct order_id promo_order_id,max(discount_applications_code) discount_applications_code from pre_actual_code
where type = 'Promo'
and order_id not in
(select
distinct order_id
from pre_actual_code
where (lower(discount_applications_code) like '%bf2024%' or lower(discount_applications_code) like '%cyber2024%'))
group by 1
)
,SF2 as(
select
date,
order_id,
email,
discount_applications_code code,
sku,
sku_name,
line_items_qty,
platform,
line_items_price,
line_items_refund,
line_item_discount,
Net_Revenue
from SF
left join actual_code
on SF.order_id = actual_code.promo_order_id
),
consolidatedview AS (
 select *, case when coalesce(sum(net_revenue) over(partition by sku,sku_name,date),0) = 0 then 'Y' else 'N' end Free_Product_Flag
 from(
 SELECT * FROM BC
 UNION ALL
 SELECT * FROM SF2)
)
,final_view as
(
 select *,
   case
   when year = 2024 then date_diff(date,'2024-11-29',day)
   when year = 2023 then date_diff(date,'2023-11-24',day)
   end day_v2
   from
   (
   select *,
   extract(year from date) year,
   extract(month from date) month,
  case
  when date between '2024-11-15' and '2024-12-14' and trim(lower(code)) in ('bf2024','cyber2024') then 'BFCM Campaign'
   when date between '2023-11-13' and '2023-12-14' and lower(code) = 'bf2023' then 'BFCM Campaign'
   when date between '2024-11-24' and '2024-12-14' and trim(lower(code)) = 'cyber2024' then 'BFCM Campaign'
  when date between '2023-11-27' and '2023-12-14' and trim(lower(code)) = 'cyber2023' then 'BFCM Campaign'
  when trim(lower(code)) is not null then 'Other-Promo'
  else 'No Promo'
  end Campaign_Name,
  case
   when date between '2024-11-15' and '2024-12-14' and trim(lower(code)) in ('bf2024','cyber2024') then 3600000
  when date between '2023-11-13' and '2023-12-10' and lower(code) = 'bf2023' then 3500000
  end Forecast,
   case
   when date = first_value(date) over(partition by email order by date) then 'New'
   else 'Existing' end Acq_type
   from consolidatedview
   )
)
select
upper(code) code,
DATE,
DATE_ADD(DATE, INTERVAL 52 week) LastYearDate,
sum(net_orders) as Orders,
sum(net_quantity) as Quantity,
sum(net_revenue) as Revenue
from
   (
   select year,month,
   date,
   code,
   platform,
   sum(net_revenue) net_revenue,
   count(distinct order_id) net_orders,
   sum(case when Free_Product_Flag = 'N' then line_items_quantity else 0 end) net_quantity,
   count(distinct email) Customers
   from final_view
   group by 1,2,3,4,5
)
where code is not null and date > '2024-01-01'
group by 1,2
