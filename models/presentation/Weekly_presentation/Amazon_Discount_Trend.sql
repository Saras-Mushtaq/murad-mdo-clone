{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "ASIN","SKU", "SKU_name","amazon_order_id"]
) }}

with Order_type as(
    select amazon_order_id,type,buyeremail
    -- case when month_between_orders>7 and type!='Checkout' then 'Checkout' else type end as type
from (select date,amazon_order_id,ASIN,SKU,SKU_name,buyeremail,promotion_ids,TIMESTAMP_DIFF(date, prev_order_date, month) AS month_between_orders,r,case  when lower(promotion_ids) LIKE '%v2%' OR r=1 THEN 'Checkout' else 'Recurring' end as type from(
select date(purchase_date) Date,a.amazon_order_id,
  ASIN,
  SKU,
  SKU_name AS SKU_name,buyeremail,LOWER(promotion_ids) promotion_ids,
  LAG(purchase_date) OVER (
      PARTITION BY buyeremail, SKU
      ORDER BY purchase_date
    ) AS prev_order_date,
 rank() over(partition by buyeremail,sku order by purchase_date asc) r
  from {{ref('Amazon_order_line')}} a
  where Sales_Channel = 'US' and order_status = 'Shipped' and coalesce(item_price_ex_tax,0)!=0   and lower(promotion_ids) like '%subscribe%' )
  order by 1 asc)
)
select date_trunc(DATE,MONTH) AS MONTH,DATE_ADD(date_trunc(DATE,MONTH), INTERVAL 1 YEAR) lyd,
*, case when revenue=price then false else true end as itemType,
Case when lower(promotion_ids) like '%subscribe and save%' or lower(promotion_ids) like '%subscribe & save%' then 'Checkout'
 when lower(promotion_ids) is not null and Discount!=0 then 'Discount'
 when Revenue_withoutdis!=price then 'Strike through'
else 'No promo'
end As Discount_Type
 from(select raw.*,case when Revenue_withoutdis>coalesce(price.price*raw.quantity,Revenue_withoutdis) then Revenue_withoutdis else coalesce(price.price*raw.quantity,Revenue_withoutdis) end as price from(
select date(purchase_date) Date,a.amazon_order_id,
  ASIN,
  SKU,
  SKU_name AS SKU_name,'Shipped' as OrderType,buyeremail,User_type,PROMOTION_IDS,
  sum(coalesce(item_promo_discount,0)) discount,
  sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
  sum(coalesce(item_price_ex_tax,0))  Revenue_withoutdis,
  sum(units_sold) as Quantity,
  from {{ref('Amazon_order_line')}} a left join (select distinct amazon_order_id, user_type from {{ref("amazon_NewExisting_V2")}} where ordertype='Shipped') b on a.amazon_order_id=b.amazon_order_id
  where Sales_Channel = 'US' and order_status = 'Shipped' and coalesce(item_price_ex_tax,0)!=0
  group by 1,2,3,4,5,6,7,8,9) raw left join 
(
select 
-- distinct 
-- item_name,
seller_sku,asin1,min(price) price from(
SELECT *
FROM `murad-data-warehouse.BigQuery.Amazon_US_SP_AllListingsReport` 
qualify rank() over (partition by ReportstartDate,ReportendDate,ReportRequestTime,item_name,seller_sku,price,asin1,price order by _daton_batch_runtime desc)=1
) 
where price!=0 group by 1,2
) price on  raw.sku=price.seller_sku and raw.asin=price.asin1 ) where amazon_order_id not in (select distinct amazon_order_id from Order_type where type='Recurring' )
-- and DATE_ADD(date_trunc(DATE,MONTH), INTERVAL 1 YEAR)<DATE_TRUNC(CURRENT_DATE(), MONTH)

