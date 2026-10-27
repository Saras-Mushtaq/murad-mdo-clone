{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "OrderType","Oders", "Customers"]
) }}
(select 
{# date(purchase_date) as Date, #}
date(last_updated_date) as Date,
DATE_TRUNC(date(last_updated_date), MONTH) AS month_start_date,
DATE_TRUNC(date(last_updated_date), WEEK(SUNDAY)) AS week_start_date,
'Shipped' as OrderType,
SUM(TOTAL_QUANTITY) AS UNITS,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) ) Revenue,
count(distinct trim(buyer_email)) Customers,
count(distinct amazon_order_id) as Oders,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) )/count(distinct amazon_order_id) as AOV
from {{ref('Amazon_Order_Header')}}
where Sales_Channel = 'US' and order_status = 'Shipped'
group by 1,2,3,4)
union all
(
  select 
{# date(purchase_date) as Date, #}
date(purchase_date) as Date,
DATE_TRUNC(date(purchase_date), MONTH) AS month_start_date,
DATE_TRUNC(date(purchase_date), WEEK(SUNDAY)) AS week_start_date,
'Ordered' as OrderType,
SUM(TOTAL_QUANTITY) AS UNITS,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) ) Revenue,
count(distinct trim(buyer_email)) Customers,
count(distinct amazon_order_id) as Oders,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) )/count(distinct amazon_order_id) as AOV
from {{ref('Amazon_Order_Header')}}
where Sales_Channel = 'US' and order_status != 'Cancelled'
group by 1,2,3,4
)