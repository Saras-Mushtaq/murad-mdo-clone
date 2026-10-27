With product_data as(
SELECT
order_id,
Date,
CancelDate,
status,
sku_id,
product_id,
product_name,
is_gift,
user_id,
name,
full_address,
buyer_email,
phone_number,
postal_code,
region_code,
fulfillment_type,
sum(sale_price) sale_price,
sum(original_price) original_price,
sum(seller_discount) as seller_discount,
sum(platform_discount) platform_discount,
-- sum(tax_amount) tax_amount,
count(product_id) order_quantity,
count(case when CancelDate is null then product_id end) Net_quantity,
count(case when CancelDate is not null then product_id end) Canceled_quantity,
count(case when is_gift then product_id end) Sample_quantity,
SUM(CASE WHEN CancelDate IS NOT NULL THEN sale_price ELSE 0 END) AS Canceled_Price,
SUM(CASE WHEN CancelDate IS NULL THEN sale_price ELSE 0 END) AS Price,
sum(Tax_amount) tax,  

from
{{ ref('tiktok_raw') }}
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
),
shipping as(
  select distinct order_id,date,
  shipping_fee/count(product_id) shipping_fee_f,
  retail_delivery_fee/count(product_id) retail_delivery_fee_f,
  original_shipping_fee/coalesce(NULLIF(count(product_id),0),1) as original_shipping_fee_f,
  shipping_fee_platform_discount/coalesce(NULLIF(count(product_id),0),1) shipping_fee_platform_discount_f,
  shipping_fee_seller_discount/coalesce(NULLIF(count(product_id),0),1) shipping_fee_seller_discount_f
  from {{ ref('tiktok_raw') }} group by 1,2,shipping_fee,retail_delivery_fee,original_shipping_fee,shipping_fee_platform_discount,shipping_fee_seller_discount
)
select
p.*,r.Return_initiate_date Return_initiate_date,r.Return_date Return_date,r.returned_quantity returned_quantity,r.returned_amount returned_amount,
s.shipping_fee_f as shipping_fee,
s.retail_delivery_fee_f as retail_delivery_fee, s.original_shipping_fee_f as original_shipping_fee,shipping_fee_platform_discount_f shipping_fee_platform_discount,shipping_fee_seller_discount_f shipping_fee_seller_discount,
p.price+p.Canceled_Price+s.shipping_fee_f +  s.retail_delivery_fee_f as GMV
from product_data p left join shipping s on p.order_id=s.order_id  and p.date=s.date
LEFT JOIN {{ ref('Tiktok_return') }} r ON r.order_id=p.order_id and r.sku_id=p.sku_id
