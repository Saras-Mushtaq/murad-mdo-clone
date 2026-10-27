{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["AdType","Country","Campaign","CampaignId"]
) }}

select *,DATE_TRUNC(DATE, WEEK(SUNDAY)) AS week_start_date,DATE_TRUNC(DATE, MONTH) AS month_start_date,DATE_ADD(date, INTERVAL 52 week) LastYearDay
,DATE_TRUNC(DATE_ADD(date, INTERVAL 52 week), WEEK(SUNDAY)) AS Last_year_week_start_date,DATE_TRUNC(DATE_ADD(date, INTERVAL 52 week), MONTH) AS Last_year_month_start_date
FROM ((Select
Brand,
AdType,
Country,
Account,
AccountID,
Date,
Campaign,
--Adgroup,
CampaignId,
Impressions,
Clicks,
Spend,
Conversions,
Unitssold,
Revenue,
0 AS NewToBrandUnitsSold,
0 AS NewToBrandSales,
0 AS NewToBrandPurchases
from murad-data-warehouse.Analytics_Ads.Amazonads_SB_US_adgrouplevel)

union all

(Select
Brand,
AdType,
Country,
Account,
AccountID,
Date,
Campaign,
--Adgroup,
CampaignId,
Impressions,
Clicks,
Spend,
Conversions,
Unitssold,
Revenue,
0 AS NewToBrandUnitsSold,
0 AS NewToBrandSales,
0 AS NewToBrandPurchases
from murad-data-warehouse.Analytics_Ads.Amazonads_SD_US_adgrouplevel)

union all

(Select
Brand,
AdType,
Country,
Account,
AccountID,
Date,
Campaign,
--Adgroup,
CampaignId,
Impressions,
Clicks,
Spend,
Conversions,
Unitssold,
AdSales as Revenue,
0 AS NewToBrandUnitsSold,
0 AS NewToBrandSales,
0 AS NewToBrandPurchases
from murad-data-warehouse.Analytics_Ads.Amazonads_SP_US_adgrouplevel)

union all

(
  (select Brand,AdType,Country,Account,AccountID,PARSE_DATE('%b %d, %Y',Date) Date,OrderName,cast(orderid as int64) OrderID,cast(Impressions as int64) Impressions,cast(Clicks as int64) clicks,cast(spend as int64) Spend,cast(Conversions as int64) Conversions,cast(units as int64) Units,cast(Revenue as int64) Revenue,0 AS NewToBrandUnitsSold,
0 AS NewToBrandSales,
0 AS NewToBrandPurchases from murad-data-warehouse.BigQuery.Murad_US_DSP_Historical_Data)
union all
(SELECT 
    'Murad' as Brand,
    'DSP' AS AdType,
    advertiserCountry as Country,
    AccountName Account,
    AccountID,
    date(date_dt) AS Date,
    ordername,
    orderId,
    SUM(COALESCE(impressions, impressions_in)) AS impressions,
    SUM(COALESCE(clicks, clicks_in)) AS clicks,
    SUM(COALESCE(totalCost, totalCost_in)) AS Spend,
    SUM(COALESCE(totalpurchases, totalpurchases_in)) AS Conversions,
    -- SUM(COALESCE(purchases, purchases_in)) AS purchases,
    SUM(totalUnitssold) Unitssold,
    SUM(COALESCE(totalSALES, totalSALES_in)) AS Revenue,
    SUM(COALESCE(totalNewToBrandUnitsSold, totalNewToBrandUnitsSold_in)) AS NewToBrandUnitsSold,
    SUM(COALESCE(totalNewToBrandSales, totalNewToBrandSales_in)) AS NewToBrandSales,
    SUM(COALESCE(totalNewToBrandPurchases, totalNewToBrandPurchases_in)) AS NewToBrandPurchases
  FROM
    (
      SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY ordername, intervalEnd, orderId, lineItemId, orderCurrency, advertiserName, advertiserId, AccountID, AccountName, lineItemName, intervalstart, advertiserCountry, advertiserTimezone, creativeAdId, creativeAdId_nu, creativeId
              ORDER BY _daton_batch_runtime DESC) AS rn
  FROM
    murad-data-warehouse.BigQuery.AmazonDSP_CampaignReport_NonAgency_NA
    )
  WHERE
    rn = 1
  group by 1,2,3,4,5,6,7,8)
)
)