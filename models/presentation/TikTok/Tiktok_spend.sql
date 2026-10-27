select * from
(with base as(
SELECT * FROM (
(Select *,date(stat_time_day) date,

row_number() over(partition by campaign_id,stat_time_day 

order by _daton_batch_runtime desc, _daton_batch_id desc) rn

from 
-- murad-data-warehouse.BigQuery.Murad_US_TiktokAds_Product_GMV_Max_Campaign_Daily
murad-data-warehouse.BigQuery.Murad_US_TiktokAds_GMV_Max_Campaign_Daily WHERE date(stat_time_day)<='2025-11-17')
)
)
Select
DATE_TRUNC(date,month) date,date as date_day,campaign_id,campaign_name, sum(cost) spend,sum(orders) orders,sum(gross_revenue) gross_revenue
from base

where 
-- cost!=0 and
cost+orders+gross_revenue!=0 and 
 rn = 1
group by 1,2,3,4
order by 1 desc)
Union ALL
(
   with base as(
SELECT * FROM (
(Select *,date(stat_time_day) date,

row_number() over(partition by campaign_id,stat_time_day 

order by _daton_batch_runtime desc, _daton_batch_id desc) rn

from 
-- murad-data-warehouse.BigQuery.Murad_US_TiktokAds_Product_GMV_Max_Campaign_Daily
murad-data-warehouse.BigQuery.Murad_US_TiktokAds_Temp_GMV_Max_Campaign_Daily WHERE date(stat_time_day)>'2025-11-17')
)

)
Select
DATE_TRUNC(date,month) date,date as date_day,campaign_id,campaign_name, sum(cost) spend,sum(orders_nu) orders,sum(gross_revenue) gross_revenue
from base

where 
-- cost!=0 and
cost+orders_nu+gross_revenue!=0 and 
 rn = 1
group by 1,2,3,4
order by 1 desc 
)