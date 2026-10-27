{{ config(enabled = False) }}

select 
date(purchase_date) as Date,
date(last_updated_date) as LastUpdatedDate,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) ) Revenue,
count(distinct trim(buyer_email)) Customers,
count(distinct amazon_order_id) as Oders,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) )/count(distinct amazon_order_id) as AOV
from murad-data-warehouse.Analytics_Amazon.Latest_Amazon_Order_Headers
where Sales_Channel = 'US' and order_status = 'Shipped'
group by 1,2