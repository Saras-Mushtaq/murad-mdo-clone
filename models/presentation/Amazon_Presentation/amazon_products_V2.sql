-- with name as(
--   select distinct asin,sku,SKU_name
-- from (select  asin,sku,sku_name,max(LENGTH(sku_name)) over(partition by asin,sku) length_name 
-- from( select 
--   ASIN,last_updated_date date,
--   SKU,
--   SKU_name AS SKU_N,
--   SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,
--   rank() over(partition by asin,sku order by last_updated_date desc) as rnk
--   from murad-data-warehouse.Analytics_Amazon.latest_amazon_order_lines
--   where Sales_Channel = 'US' and order_status = 'Shipped' 
-- ) 
-- where rnk=1)
-- where length(SKU_name)=length_name
-- ),
-- base as(
--   (select
--   date(last_updated_date) Date,
--   ASIN,
--   SKU,
--   SKU_name AS SKU_N,
--   SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,'Shipped' as OrderType,
--   sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
--   sum(units_sold) as Quantity,
--   count(distinct amazon_order_id) as Orders
--   from murad-data-warehouse.Analytics_Amazon.latest_amazon_order_lines
--   where Sales_Channel = 'US' and order_status = 'Shipped'
--   group by 1,2,3,4,5,6
-- )
-- Union all
-- (select
--   date(purchase_date) Date,
--   ASIN,
--   SKU,
--   SKU_name AS SKU_N,
--   SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,'Ordered' as OrderType,
--   sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
--   sum(units_sold) as Quantity,
--   count(distinct amazon_order_id) as Orders
--   from murad-data-warehouse.Analytics_Amazon.latest_amazon_order_lines
--   where Sales_Channel = 'US' and order_status != 'Cancelled'
--   group by 1,2,3,4,5,6
-- )
-- )
-- select b.Date,b.asin,b.sku,SPLIT(n.SKU_name, ' - ')[OFFSET(0)] AS SKU_name,ordertype,revenue,quantity,orders from 
-- base b left join name n on b.asin=n.asin and b.sku=n.sku
{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "ASIN","SKU", "SKU_name"]
) }}

with 
base as(
  (select
  date(last_updated_date) Date,
  ASIN,
  SKU,
  SKU_name AS SKU_N,
  SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,'Shipped' as OrderType,
  sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
  sum(units_sold) as Quantity,
  count(distinct amazon_order_id) as Orders
  from {{ref('Amazon_order_line')}}
  where Sales_Channel = 'US' and order_status = 'Shipped'
  group by 1,2,3,4,5,6
)
Union all
(select
  date(purchase_date) Date,
  ASIN,
  SKU,
  SKU_name AS SKU_N,
  SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,'Ordered' as OrderType,
  sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
  sum(units_sold) as Quantity,
  count(distinct amazon_order_id) as Orders
  from {{ref('Amazon_order_line')}}
  where Sales_Channel = 'US' and order_status != 'Cancelled'
  group by 1,2,3,4,5,6
)
),
name as(
  select distinct asin,sku,SKU_name
from (select  asin,sku,sku_name,max(LENGTH(sku_name)) over(partition by asin,sku) length_name 
from( select 
  ASIN, date,
  SKU,
  SKU_name,
  rank() over(partition by asin,sku order by date desc) as rnk
  from base
) 
where rnk=1)
where length(SKU_name)=length_name
)
select b.Date,b.asin,b.sku, n.SKU_name AS SKU_name,ordertype,revenue,quantity,orders from 
base b left join name n on b.asin=n.asin and b.sku=n.sku