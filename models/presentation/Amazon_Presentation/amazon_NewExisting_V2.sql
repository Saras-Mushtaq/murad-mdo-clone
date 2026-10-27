{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "User_type","OrderType", "amazon_order_id"]
) }}

select 
Date,amazon_order_id,
OrderType,
case when rnk = 1 then 'New'
else 'Existing'
end User_type,
trim(buyer_email) Customer,
SUM(TOTAL_QUANTITY) AS UNITS,
sum(coalesce(price_ex_tax,0) - coalesce(total_promotion_discount,0) ) Revenue,
from
  (
    (select
  *,date(Last_Updated_Date) as date,
  dense_rank() over(partition by trim(buyer_email) order by date_trunc(purchase_date,MONTH)) rnk,'Shipped' as OrderType,
  from {{ref('Amazon_Order_Header')}}
  where Sales_Channel = 'US' and order_status = 'Shipped')
  union all
  (
    select
  *,purchase_date date,
  dense_rank() over(partition by trim(buyer_email) order by date_trunc(purchase_date,MONTH)) rnk,'Ordered' as OrderType,
  from {{ref('Amazon_Order_Header')}}
  where Sales_Channel = 'US' and order_status != 'Cancelled'
  )
  )
group by 1,2,3,4,5