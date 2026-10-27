{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["platform", "strategy"]
) }}
with base as(select 
date_start date,
strategy,
platform,
sum(impressions) impressions,
sum(clicks) clicks,
sum(spend) spend,
round(sum(conversions),0) orders,
sum(revenue) revenue,
SUM(coalesce(`7 Day Click`,0)) `7 Day Click`,
SUM(coalesce(`7 Day Click Order`,0)) `7 Day Click Order`,
SUM(coalesce(`1 Day View`,0)) `1 Day View`,
SUM(coalesce(`1 Day View Order`,0)) `1 Day View Order`
from {{ref('Marketing_Platform')}}
where platform != 'Microsoft Ads'
group by 1,2,3),

base2 as
(
  
select * from (select distinct strategy,platform from base
where date >= '2022-01-01')

cross join

(SELECT 
date_value AS date
FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates
)

,base3 as
(
  select a.*,
  coalesce(impressions,0)  impressions,
  coalesce(clicks,0) clicks,
  coalesce(spend,0) spend,
  coalesce(orders,0) orders,
  coalesce(revenue,0) revenue,
  coalesce(`7 Day Click`,0) `7 Day Click`,
coalesce(`7 Day Click Order`,0) `7 Day Click Order`,
coalesce(`1 Day View`,0) `1 Day View`,
coalesce(`1 Day View Order`,0) `1 Day View Order`
  from base2 a
  left join base b
  on a.date = b.date and a.strategy = b.strategy and a.platform = b.platform
)

select a.*except(`7 Day Click`,`7 Day Click Order`,`1 Day View`, `1 Day View Order`),A.`7 Day Click` TY_7_Day_Click,a.`7 Day Click Order` TY_7_Day_Click_Order,a.`1 Day View` TY_1_Day_View, a.`1 Day View Order` TY_1_Day_View_Order ,
-- b.impressions LY_impressions,
-- b.clicks LY_clicks,
-- b.spend LY_spend,
-- b.orders LY_orders,
-- b.revenue LY_revenue,
-- coalesce(b.`7 Day Click`,0) LY_7_Day_Click,
-- coalesce(b.`7 Day Click Order`,0) LY_7_Day_Click_Order,
-- coalesce(b.`1 Day View`,0) LY_1_Day_View,
-- coalesce(b.`1 Day View Order`,0) LY_1_Day_View_Order,

-- c.impressions LW_impressions,
-- c.clicks LW_clicks,
-- c.spend LW_spend,
-- c.orders LW_orders,
-- c.revenue LW_revenue,
-- coalesce(c.`7 Day Click`,0) LW_7_Day_Click,
-- coalesce(c.`7 Day Click Order`,0) LW_7_Day_Click_Order,
-- coalesce(c.`1 Day View`,0) LW_1_Day_View,
-- coalesce(c.`1 Day View Order`,0) LW_1_Day_View_Order,

from base3 a
-- left join base3 b
-- on b.date = DATE_SUB(a.date, INTERVAL 52 week) and a.strategy = b.strategy
-- and a.platform = b.platform
-- left join base3 c
-- on c.date = DATE_SUB(a.date, INTERVAL 1 week) and a.strategy =  c.strategy
-- and a.platform = c.platform
where a.impressions + a.clicks + a.spend + a.orders + a.revenue  != 0