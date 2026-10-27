{{ config(
    materialized='table',
    partition_by={
      "field": "purchase_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "last_updated_date","amazon_order_id", "SKU"]
) }}

WITH base AS (
  SELECT 'Murad Amazon' AS store,
 date(DATETIME(cast(last_updated_date as timestamp) ,"America/Los_Angeles")) last_updated_date,
  CAST(ReportstartDate AS DATE) ReportstartDate,
  CAST(ReportendDate AS DATE) ReportendDate,
  CAST(amazon_order_id AS STRING) AS amazon_order_id,
  sellingPartnerId,
  marketplaceName,
  --date(purchase_date) purchase_date,/*Use this line for validation as Amazon Reports and Amazon API stores data in UTC */
  date(DATETIME(cast(purchase_date as timestamp) ,"America/Los_Angeles")) purchase_date,
  order_status,
  fulfillment_channel,
  CASE WHEN sales_channel = 'Amazon.com' THEN 'US'
  WHEN sales_channel = 'Non-Amazon' THEN 'Non-Amazon'
  WHEN sales_channel = 'Amazon.ca' THEN 'Canada'
  ELSE sales_channel END AS Sales_Channel,
  product_name AS SKU_Name,
  sku AS SKU,
  asin AS ASIN,
  item_status, 
  CAST(quantity AS INT64) units_sold,
  currency,
  CAST(item_price AS FLOAT64) AS item_price_ex_tax,
  CAST((item_price+shipping_price+gift_wrap_price) AS FLOAT64) AS value_ex_tax,
  CAST(item_tax AS float64) AS item_tax,
  CAST(shipping_price AS FLOAT64) AS shipping_price,
  CAST(shipping_tax AS FLOAT64) AS shipping_tax,
  CAST(gift_wrap_price AS FLOAT64) giftwrap_price,
  CAST(gift_wrap_tax AS FLOAT64) giftwrap_tax,
  CAST(item_promotion_discount AS FLOAT64) AS item_promo_discount,
  CAST(ship_promotion_discount AS FLOAT64) AS shipping_promo_discount,
  promotion_ids,
  ship_city AS city,
  ship_state AS state,
  CAST(ship_postal_code AS STRING) zipcode,
  ship_country AS country,
  is_replacement_order,
  CAST(original_order_id AS STRING) original_order_id,
  _daton_user_id,
  _daton_batch_runtime,
  _daton_batch_id,
  ROW_NUMBER() OVER (PARTITION BY amazon_order_id, asin ORDER BY _daton_batch_runtime DESC) AS row_num
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
)
SELECT base.store,
base.amazon_order_id,
base.purchase_date,
base.last_updated_date,
base.order_status,
base.Sales_Channel,
base2.BuyerEmail,
SKU_name,
SKU,
asin,
item_status,
units_sold,
currency,
item_price_ex_tax,
item_tax,
item_price_ex_tax+item_tax AS item_price_inc_tax,
shipping_price AS shipping_price_ex_tax,
shipping_tax,
shipping_price+shipping_tax AS shipping_price_inc_tax,
giftwrap_price,
giftwrap_tax,
item_promo_discount,
shipping_promo_discount,
promotion_ids
FROM base left join base2 on base.amazon_order_id=base2.AmazonOrderId
WHERE row_num = 1
AND order_status != 'Cancelled'
AND Sales_Channel != 'Non-Amazon'