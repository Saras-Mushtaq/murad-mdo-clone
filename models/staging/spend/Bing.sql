select 
date_start date,
strategy,
platform,
sum(impressions) impressions,
sum(clicks) clicks,
sum(spend) spend,
round(sum(conversions),0) orders,
sum(revenue) revenue
from murad-data-warehouse.Analytics_Ads.DS_Combined_CampaignLevel
where platform = 'Microsoft Ads'
group by 1,2,3