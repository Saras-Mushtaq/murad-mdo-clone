{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "Country","Order_ID", "New_Customer_Flag"]
) }}

select 
Date,
amazon_order_id Order_ID,
trim(buyer_email) Customer_ID,
-- OrderType,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) ) Revenue,
ship_country Country,
ship_state State,
ship_postal_code Zip_Code,
case when rnk = 1 then True
else False
end New_Customer_Flag,
'-' as DMA,
ship_city City
from
  (
    select
  *,purchase_date date,
  dense_rank() over(partition by trim(buyer_email) order by date_trunc(purchase_date,MONTH)) rnk,'Ordered' as OrderType,
  from {{ref('Amazon_Order_Header')}}
  where Sales_Channel = 'US' and order_status != 'Cancelled'
  )
group by 1,2,3,5,6,7,8,9,10