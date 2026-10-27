with base as(
SELECT 
  date(PARSE_DATE('%m/%d/%y', MonthStartDate)) as MonthStartDate,
  CAST(OverallRevenueForecastExcludingTTS AS FLOAT64) AS Overall_Revenue_Forcast_Excluding_TTS,
  CAST(RechargeRecurringRevenueForecast AS FLOAT64) AS RechargeRecurringRevenueForecast,
  CAST(OverallRevenueForecastExcludingTTSRecharge AS FLOAT64) AS OverallRevenueForecastExcludingTTSRecharge, 
  CAST(OverallMarketingSpendProjection AS FLOAT64) AS Overall_Marketing_Spend_Projection,
  CAST(PaidSearchSpendProjection AS FLOAT64) AS Paid_Search_Spend_Projection,
  CAST(PaidSocialSpendProjection AS FLOAT64) AS Paid_Social_Spend_Projection,
  CAST(PerformanceMaxSpendProjection AS FLOAT64) AS PerformanceMaxSpendProjection,
--   CAST(Tiktok_Marketing_Spend_Projection__Not_Comission_Spend_ AS FLOAT64) AS Tiktok_Marketing_Spend_Projection,
  CAST(AffiliateSpendProjection AS FLOAT64) AS Affiliate_Marketing_Spend_Projection,
--   CAST(Bing_Marketing_Spend_Projection AS FLOAT64) AS Bing_Marketing_Spend_Projection,
--   CAST(TTD_Marketing_Spend_Projection AS FLOAT64) AS TTD_Marketing_Spend_Projection
from murad-data-warehouse.BigQuery.Murad_US_Goal_Murad_Target_Sheet_BQ_Monthly_Goals
where date(PARSE_DATE('%m/%d/%y', MonthStartDate))<=CURRENT_DATE()

)
select base.*,
Overall_revenue_achieved,non_tts_rev,online_rev,
coalesce(`Paid Search`,0) Paid_Search,
coalesce(`Paid Social`,0) Paid_Social,
coalesce(`Performance Max`,0) Performance_Max,
coalesce(Affiliate,0) Affiliate,
-- coalesce(TikTok,0) TikTok,
-- coalesce(Bing,0) Bing,
-- coalesce(TTD,0) TTD, 
coalesce(`Paid Search`,0)+coalesce(`Paid Social`,0)+coalesce(`Performance Max`,0)+coalesce(Affiliate,0) as Total_spend
from base
left join 
(
    with spend as(SELECT *
FROM (
    SELECT 
        DATE_TRUNC(DATE, MONTH) AS DATE,
        TIER_1,
        SPEND
    FROM `murad-data-warehouse.BigQuery.RockerBox_BQ`
    WHERE TIER_1 IN ('Performance Max','Affiliate','Paid Search','Paid Social')
)
PIVOT (
    SUM(SPEND)
    FOR TIER_1 IN (
        'Performance Max',
        'Affiliate',
        'Paid Search',
        'Paid Social'
    )
)
ORDER BY DATE),
rev as
(
  SELECT DATE_TRUNC(order_created_at , MONTH) AS DATE,SUM(NET_REVENUE) Overall_revenue_achieved,
  SUM(CASE WHEN PLATFORM!='Tiktok' then NET_REVENUE end)  as non_tts_rev,SUM(CASE WHEN PLATFORM not in ('Tiktok' ,'Recurring') then NET_REVENUE end)  as online_rev, SUM(CASE WHEN PLATFORM='Tiktok' then NET_REVENUE end)  as tts_rev,SUM(CASE WHEN PLATFORM='Recurring' then NET_REVENUE end)  as rec_rev from {{ref('BCAndShopifyData') }} group by 1

)
select a.*,Overall_revenue_achieved,non_tts_rev,online_rev from spend a left join rev b on a.date=b.date
where a.date >= '2026-01-01'
) sp
on base.MonthStartDate=sp.date
