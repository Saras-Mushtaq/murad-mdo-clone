{{ config(enabled = False) }}

select
  purchase_date,
  last_updated_date,
  ASIN,
  SKU,
  SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,
  sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
  sum(units_sold) as Quantity,
  count(distinct amazon_order_id) as Orders
  from murad-data-warehouse.Analytics_Amazon.latest_amazon_order_lines
  where Sales_Channel = 'US' and order_status = 'Shipped'
  group by 1,2,3,4,5