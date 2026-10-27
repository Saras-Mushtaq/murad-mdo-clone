With order_data as(
SELECT
order_id,
Date,
CancelDate as CancelDate,
status,
-- sku_id,
-- product_id,
-- product_name,
-- is_gift,
user_id,
name,
full_address,
buyer_email,
phone_number,
postal_code,
region_code,
fulfillment_type,
SUM(total_amount) as Total_price,
sum(original_price) original_price,
sum(sale_price) sale_price,
sum(seller_discount) as seller_discount,
sum(platform_discount) platform_discount,
sum(tax_amount) tax,
sum(original_shipping_fee) as Original_shipping_fee,
Sum(shipping_fee) as shipping_fee,
count(product_id) order_quantity,
count(case when CancelDate is null then product_id end) Net_quantity,
count(case when CancelDate is not null then product_id end) Canceled_quantity,
count(case when is_gift then product_id end) Sample_quantity,
SUM(CASE WHEN CancelDate IS NOT NULL THEN sale_price ELSE 0 END) AS Canceled_Price,
SUM(CASE WHEN CancelDate IS NULL THEN sale_price ELSE 0 END) AS Price,
sum(retail_delivery_fee) as retail_delivery_fee,
sum(shipping_fee_platform_discount) shipping_fee_platform_discount,
sum(shipping_fee_seller_discount) shipping_fee_seller_discount
from
{{ ref('tiktok_raw') }}
group by 1,2,3,4,5,6,7,8,9,10,11,12
),
base as(
select * EXCEPT(total_price,Original_shipping_fee,shipping_fee,shipping_fee_platform_discount,shipping_fee_seller_discount,retail_delivery_fee),
  total_price / IF(order_quantity = 0, 1, order_quantity) AS Total_price,
  Original_shipping_fee / IF(order_quantity = 0, 1, order_quantity) AS Original_shipping_fee,
  shipping_fee / IF(order_quantity = 0, 1, order_quantity) AS Shipping_fee,
  shipping_fee_platform_discount / IF(order_quantity = 0, 1, order_quantity) AS shipping_fee_platform_discount,
  shipping_fee_seller_discount / IF(order_quantity = 0, 1, order_quantity) AS shipping_fee_seller_discount,
  retail_delivery_fee / IF(order_quantity = 0, 1, order_quantity) retail_delivery_fee
  from order_data
)
select A.*,b.Return_date,b.returned_quantity returned_quantity,b.returned_amount returned_amount from(
select *,sale_price+Shipping_fee+retail_delivery_fee GMV,CASE WHEN CancelDate IS NOT NULL THEN sale_price ELSE 0 END AS Canceled_Amount,
case when 
order_id in (select distinct order_id from {{ ref('Tiktok_return') }} where return_status!='RETURN_OR_REFUND_REQUEST_CANCEL') 
then true else false end AS has_returns
FROM BASE
) A
LEFT JOIN
(
  select order_id,max(Return_date) Return_date,max(Return_initiate_date) Return_initiate_date,sum(returned_quantity) returned_quantity,sum(returned_amount) returned_amount from {{ ref('Tiktok_return') }} group by 1
) B ON A.order_id=b.order_id