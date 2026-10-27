
{{ config(
    materialized='table',
    partition_by={
      "field": "order_created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "New_Bucket","SKU", "order_id"]
) }}

With Potential_GWP_Orders as
(
  SELECT distinct id FROM {{ref("BC_US_Orders" ) }} 
where coalesce(cast(p_price_ex_tax as numeric),0) = 0
and extract(year from DATE(date_created)) >= 2022
),

order_type as
(

SELECT  
distinct ecommerce,lower(type) ttype
FROM `murad-data-warehouse.BigQuery.Recharge_Orders` 
left join unnest(external_order_id)

union all

SELECT  
distinct ecommerce,lower(type) ttype
FROM `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders`
left join unnest(external_order_id)
),

BC AS
(
    SELECT
    DATE(date_created) AS order_created_at,
    CAST(id AS STRING) AS order_id,
    ba_email as email,
    c_code AS c_code,
    p_sku as SKU,
    p_name as SKU_Name,
    p_quantity as line_items_quantity,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) line_items_price,
    avg(cast(refunded_amount as numeric)) line_items_refund,
    sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) line_item_discount,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) - sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) - sum(cast(p_refund_amount as numeric)) Net_Revenue  
  FROM {{ref("BC_US_Orders" ) }}
  WHERE LOWER(status) IN ('awaiting fulfillment','awaiting shipment','awaiting pickup','completed','shipped','partially shipped','partially refunded')
  AND DATE(date_created) <='2024-02-29'
  group by 1,2,3,4,5,6,7
),

base as(select  
extract(year from order_created_at) year,
extract(month from order_created_at) month,
extract(quarter from order_created_at) quarter,
order_created_at,
order_id,sku,
lower(trim(c_code)) as c_code,
case when lower(trim(c_code)) is null then 'N'
else 'Y' end code_string,
case 
when lower(trim(c_code)) is not null 
and (lower(trim(c_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(c_code)) in (select distinct lower(code) from `murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes`)
or lower(trim(c_code)) like '%autodelivery%')
then 'Promo'
when ttype = 'recurring' then 'Recurring Subscription'
when lower(trim(c_code)) is not null then 'Loyalty'
WHEN SKU IN ('15348', '15118', '10903', '60361', '92807', '15272', '18001', '15409', '15293', '10915', '15232', 
                     '92809', '15391', '60391', '15396', '15288', '92804', '15269', '92808', '10803', '92803', '15384', 
                     '15305', '15414', '65993', '15403', '92806', '15306', '15300', '10035', '92824', '10034', '10160', 
                     '18000', '10925', '92819', '92802', '15385', 'BUNDLEM111', 'BUNDLEM110', 'BUNDLEM112') 
             AND (order_created_at BETWEEN '2023-12-11' AND '2023-12-28' )
        THEN 'Excess Promo'
WHEN SKU IN ('10034', '80885', '15385', '10925', '15293', '92701', '92687')
             AND (order_created_at BETWEEN '2023-09-21' AND '2023-09-29')
        THEN 'Excess Promo'
WHEN SKU IN ('80897', '80885', '80886', '15094', '10026', '15288', '10040C', '10925', '10890', '10905', '10903', 
                     '92709', '92700')
             AND (order_created_at BETWEEN '2022-12-06' AND '2022-12-30')
        THEN 'Excess Promo'
        WHEN SKU IN ('92696', '92693', '92691', '92689')
             AND (order_created_at BETWEEN '2022-12-19' AND '2022-12-30')
        THEN 'Excess Promo'
WHEN (SKU = '18003' AND (order_created_at between '2024-02-01' and '2024-02-29')) THEN 'Excess Promo'
        WHEN (SKU = '18004' AND (order_created_at between '2024-02-01' and '2024-02-29')) THEN 'Excess Promo'
        WHEN (SKU = '18001' AND (order_created_at between '2024-02-01' and '2024-02-29')) THEN 'Excess Promo'
WHEN (SKU = '18005' AND (order_created_at between '2024-02-01' and '2024-02-29')) THEN 'Excess Promo'
when lower(trim(c_code)) is null then 'No-Promo'
end New_Bucket,
net_revenue
from BC
left join order_type
on BC.order_id = order_type.ecommerce
where date(order_created_at) >= '2022-01-01')

,base2 as(
select 
*except(New_Bucket),
case
when (order_id in (select distinct cast(id as string) from Potential_GWP_Orders)
and order_id not in (select distinct order_id from base where New_Bucket in ('Promo','Loyalty','Excess Promo')))
then'GWP'
else New_Bucket
end New_Bucket
from base
)


-- select 
-- -- year,
-- -- sum(net_revenue)
-- distinct new_bucket
-- from base2
-- -- group by 1

select *
from(
select
order_created_at,
New_Bucket,
order_id,sku,'null' as promo_type,
sum(net_revenue) net_revenue,
-- count(distinct order_id) id
from base2
group by 1,2,3,4
)
-- pivot
-- (
--   sum(net_revenue)
--     for New_Bucket in ("Promo",'Excess Promo',"Loyalty",'New_Bucket_GWP','recurring','New_Bucket_No_Promo')
-- )
