{{ config(
    materialized='table',
    partition_by={
      "field": "date_start",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["Platform", "Strategy"]
) }}
Select
'Facebook Ads' as Platform,
campaign_id,
campaign_name,
CASE
            WHEN LOWER(campaign_name) LIKE '%national%' then 'National'
            WHEN LOWER(campaign_name) LIKE '%retail%' then 'Retail'
            WHEN campaign_name='tin_murad_us_soc_meta_dr_friendsandfamily__atc' THEN 'Consideration'
            WHEN (campaign_name in ('H10 - US - Social - META - Brand - Awareness - Partnership Rebrand','H10 - US - Social - META - Brand - Awareness - Video Views Rebrand') and date_start between '2026-05-07' and '2026-06-30') or ((LOWER(campaign_name) LIKE '%amazon%' or LOWER(campaign_name) LIKE '%measured%' ) AND date_start between '2026-05-07' and '2026-07-04') Then 'Awareness - Amazon'
            WHEN LOWER(campaign_name) LIKE '%_awr_%' OR LOWER(campaign_name) LIKE '%_aw%' OR LOWER(campaign_name) LIKE '%_prosp%' THEN 'Awareness'
            WHEN LOWER(campaign_name) LIKE '%_cnsd_%' OR LOWER(campaign_name) LIKE '%_cd%' or LOWER(campaign_name) LIKE '%traf%' OR LOWER(campaign_name) LIKE '%consideration%' THEN 'Consideration'
            WHEN LOWER(campaign_name) LIKE '%_cvr_%' OR LOWER(campaign_name) LIKE '%_cn%' or LOWER(campaign_name) LIKE '%sales%' OR LOWER(campaign_name) LIKE '%conversion%' or LOWER(campaign_name)='dx - aiugc' or LOWER(campaign_name)='dx - rdscs' or LOWER(campaign_name) LIKE '%dx%' THEN 'Conversion'

            else 'Others'
END AS Strategy,
adset_id,
adset_name,
date_start,
impressions,
clicks,
spend,
conversion as conversions,
conversion_value as Revenue,
coalesce(`7 Day Click`,0) `7 Day Click`,
coalesce(`7 Day Click Order`,0) `7 Day Click Order`,
coalesce(`1 Day View`,0) `1 Day View`,
coalesce(`1 Day View Order`,0) `1 Day View Order`,
campaign_filters,
case when campaign_name like '%_CN' then 'Conversion Marketing'
else 'Brand Marketing'
end as marketing_type,
from murad-data-warehouse.Analytics_Ads.FacebookAds_US_Dedup

UNION ALL

-- Select
-- 'Google Ads' as Platform,
-- campaign_id,
-- campaign_name,
-- ad_group_id as adset_id,
-- ag_group_name as adset_name,
-- date_start,
-- impressions,
-- clicks,
-- spend,
-- conversions,
-- conversions_value as Revenue,
-- 'N/A' as campaign_filters
-- from murad-data-warehouse.Analytics_Ads.GoogleAds_US_AdGroupLevel_Dedup

select
'Google Ads' as Platform,
cast(campaign_id as string) campaign_id,
campaign_name,
 CASE
        WHEN LOWER(campaign_name) LIKE '%shopping%'  THEN 'Shopping'
        WHEN LOWER(campaign_name) LIKE '%youtb%' OR LOWER(campaign_name) LIKE '%youtube%' OR LOWER(campaign_name) LIKE '%video%'THEN 'YouTube'
        WHEN LOWER(campaign_name) LIKE '%retail%' THEN 'Retail'
        WHEN LOWER(campaign_name) LIKE '%non%' THEN 'Non-Brand'
        WHEN LOWER(campaign_name) LIKE '%dsa%' THEN 'DSA'
        WHEN LOWER(campaign_name) LIKE '%pmax%' THEN 'PMAX'
        WHEN LOWER(campaign_name) LIKE '%demand%' OR LOWER(campaign_name) LIKE '%discovery%' THEN 'Discovery'
        WHEN LOWER(campaign_name) LIKE '%display%' THEN 'display'
        WHEN LOWER(campaign_name) LIKE '%core%' OR LOWER(campaign_name) LIKE '%general%' THEN 'Pure Brand'
        ELSE 'Brand+Product'
END AS Startegy,
"-" adset_id,
"-" adset_name,
segment_date as date_start,
cast(metrics_impressions as int) impressions,
cast(metrics_clicks as int) clicks,
cast(metrics_cost_micros as int)/1000000 as spend,
metrics_conversions conversions,
sales as Revenue,
0 `7 Day Click`,
0 `7 Day Click Order`,
0 `1 Day View`,
0 `1 Day View Order`,
'N/A' as campaign_filters,
case
when (lower(campaign_name) like '%yt%') or (lower(campaign_name) like '%youtube%') or (lower(campaign_name) like '%youtb%') OR (LOWER(campaign_name) LIKE '%Video%') then 'Brand Marketing'
else 'Conversion Marketing'
end Marketing_Type
from
(select *,coalesce(campaign.id,campaign.id_in) as campaign_id,campaign.name as campaign_name,
metrics.clicks as metrics_clicks,
metrics.impressions as metrics_impressions,
metrics.conversions as metrics_conversions,
coalesce(metrics.conversions_value,metrics.conversions_value_bn) as sales,
metrics.cost_micros as metrics_cost_micros,
segments.date as segment_date,
row_number() over(partition by segments.date,coalesce(campaign.id,campaign.id_in) order by _daton_batch_runtime desc) rn
from `murad-data-warehouse.BigQuery.Murad_US_GoogleAds_Campaign`
left join unnest (campaign) as campaign
left join unnest (metrics) as metrics
left join unnest(segments) as segments)
where rn = 1

UNION ALL

Select
'Microsoft Ads' as Platform,
CampaignId as campaign_id,
CampaignName as campaign_name,
'Not Defined' Startegy,
AdGroupId as adset_id,
AdGroupName as adset_name,
date_start,
impressions,
clicks,
spend,
conversions,
Revenue,
0 `7 Day Click`,
0 `7 Day Click Order`,
0 `1 Day View`,
0 `1 Day View Order`,
'N/A' as campaign_filters,
case when CampaignName like '%_CN' then 'Conversion Marketing'
else 'Brand Marketing'
end as marketing_type,
from murad-data-warehouse.Analytics_Ads.MicrosoftAds_US_Adlevel_Dedup