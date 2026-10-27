{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["sku","type", "order_id"]
) }}

with f_base as(SELECT
  distinct date(created_at) Date,oi.order_id,oi.line_items_sku AS sku,
  oi.line_items_title AS sku_name,b.type,
  coalesce(CAST(oi.line_items_quantity AS FLOAT64),0) Quantity_ordered,
  coalesce(CAST(oi.line_items_price AS FLOAT64),0) line_items_price,
   coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0) discount,
  coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0) Total_rev,
  round(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0) - coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0),1) Discounted_Revenue,
  CASE 
      WHEN COALESCE(CAST(oi.line_items_discount_line_item AS FLOAT64), 0) != 0 
        THEN COALESCE(CAST(oi.line_items_quantity AS FLOAT64), 0)
      ELSE 0 
    END AS discounted_quantity_without_strike_through
FROM
  {{ref("Shopify_US_OrderLines")}} oi left join (select distinct order_id,type from {{ref("BCAndShopifyData")}} ) b on oi.order_id=b.order_id
   where date(created_at)>'2024-02-29' and 
   oi.order_id in (select distinct order_id from {{ref("Shopify_US_OrderLines")}} where lower(source_name) like '%web%')
   and (gwp_product=false and loyalty_product=false and free_product=false) 
--   group by 1,2,3,4,5
  )
select D.*except(Discounted_Revenue,total_MSRP),round(Discounted_Revenue) Discounted_Revenue,round(total_MSRP) total_MSRP,case when round(Discounted_Revenue)=round(total_MSRP) then false else true end as discounted_quantity
,granular_type 
from(
select f_base.*,date_trunc(date,month) as Month_start_date,  
case when coalesce(cast(ff.price as numeric),0)<=line_items_price then line_items_price else coalesce(cast(ff.price as numeric),line_items_price)  end
 list_price,round(case when coalesce(cast(ff.price as numeric),0)<=line_items_price then line_items_price else coalesce(cast(ff.price as numeric),line_items_price)  end * Quantity_ordered,1) total_MSRP, from  
f_base left join 
(SELECT DISTINCT * FROM {{ref("CompareAtPrice")}}) ff on 
lower(trim(f_base.sku))=lower(trim(ff.sku)) and lower(trim(f_base.sku_name))=lower(trim(ff.sku_name)) and
 f_base.date>=date(ff.start_date) and f_base.date<date(ff.end_date)
order by date,order_id) D 
LEFT JOIN (select distinct order_id,sku,name,net_revenue,granular_type from {{ref("product_level_discount_trend")}}) P on D.order_id=P.order_id and D.sku=P.sku and round(d.Discounted_Revenue)=round(p.net_revenue)
 where list_price!=0 and Total_rev!=0 and date < DATE_TRUNC(CURRENT_DATE(), MONTH) 