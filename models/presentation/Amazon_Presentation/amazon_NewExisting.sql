{{ config(enabled = False) }}

select 
date(purchase_date) as Date,
LastUpdatedDate,
case when rnk = 1 then 'New'
else 'Existing'
end User_type,
trim(buyer_email) Customer,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) ) Revenue,
from
  (select
  *,
  dense_rank() over(partition by trim(buyer_email) order by date_trunc(purchase_date,MONTH)) rnk,
  date(last_updated_date) as LastUpdatedDate
  from murad-data-warehouse.Analytics_Amazon.Latest_Amazon_Order_Headers
  where Sales_Channel = 'US' and order_status = 'Shipped'
  )
group by 1,2,3,4