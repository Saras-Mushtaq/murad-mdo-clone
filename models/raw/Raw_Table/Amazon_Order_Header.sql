{{ config(
    materialized='table',
    partition_by={
      "field": "purchase_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "Sales_Channel","amazon_order_id", "order_status"]
) }}

WITH BASE1 AS 
(
  SELECT *,
  ROW_NUMBER() OVER (PARTITION BY amazon_order_id, asin ORDER BY _daton_batch_runtime DESC) AS row_n
  FROM `murad-data-warehouse.BigQuery.Amazon_US_SP_FlatFileAllOrdersReportbyLastUpdate`
),

BASE2 AS
(
  SELECT AmazonOrderId, deduplicated.BuyerEmail as BuyerEmail
  from
  (
      SELECT a.* except(BuyerInfo),
      BI.BuyerEmail as BuyerEmail,
      row_number() over(partition by AmazonOrderId order by _daton_batch_runtime desc) as row_n
      FROM murad-data-warehouse.BigQuery.Amazon_US_SP_ListOrder as a
      left join unnest (BuyerInfo) BI
  ) as deduplicated
  where row_n = 1
),

Base3 as(SELECT
B1.amazon_order_id amazon_order_id,
B2.BuyerEmail as buyer_email,
--date(B1.purchase_date) purchase_date,/*Use this while validation as Amazon UI store report in UTC */
--date(B1.last_updated_date) last_updated_date,/*Use this while validation as Amazon UI store report in UTC */
date(DATETIME(cast(B1.purchase_date as timestamp) ,"America/Los_Angeles")) purchase_date,
date(DATETIME(cast(B1.last_updated_date as timestamp) ,"America/Los_Angeles")) last_updated_date,
B1.order_status order_status,
CASE WHEN B1.sales_channel = 'Amazon.com' THEN 'US'
WHEN B1.sales_channel = 'Non-Amazon' THEN 'Non-Amazon'
WHEN B1.sales_channel = 'Amazon.ca' THEN 'Canada'
ELSE B1.sales_channel END AS Sales_Channel,
B1.fulfillment_channel,
B1.ship_city,
B1.ship_state,
B1.ship_postal_code,
B1.ship_country,
B1.PROMOTION_IDs,
sum(quantity) as total_quantity,
max(currency) as currency,
sum(item_price) as price_ex_tax,
sum(item_tax) as total_tax,
sum(item_price) + sum(item_tax) as price_inc_tax,
sum(shipping_price) as shipping_price_ex_tax,
sum(shipping_tax) as total_shipping_tax,
sum(shipping_price) + sum(shipping_tax) as shipping_price_inc_tax,
sum(gift_wrap_price) total_gift_wrap_price,
sum(gift_wrap_tax) total_gift_wrap_tax,
sum(item_promotion_discount) total_promotion_discount,
sum(ship_promotion_discount) total_ship_promotion_discount
FROM BASE1 AS B1
LEFT JOIN BASE2 AS B2
ON B1.amazon_order_id = B2.AmazonOrderId
where row_n = 1
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
),

BASE4 AS
(
select t1.* except(buyer_email),
case
when t1.buyer_email is not null then t1.buyer_email
else t2.buyer_email
end as buyer_email
from base3 t1
left join 
(Select amazon_order_id,min(buyer_email) as buyer_email
from(select *
        from
        (select *,
        row_number() over(partition by amazon_order_id,sku order by _daton_batch_runtime desc) row_n
        from murad-data-warehouse.BigQuery.Amazon_US_SP_FBAAmazonFulfilledShipmentsReport
        ) as x 
  where row_n = 1
) as y
group by amazon_order_id
) as t2
on t1.amazon_order_id = t2.amazon_order_id
)

select * From base4
