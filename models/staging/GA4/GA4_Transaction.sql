
select
DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) date,
event_name,
CASE
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid search' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%cpc%' THEN 'Paid Search'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'sms' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%sms%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%text%' THEN 'SMS'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%tiktokshop%' THEN 'TikTok Shop'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Source) = 'shopify' and lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%facebook%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'web' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'shop' THEN 'FB IG Shop'
   WHEN (lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid social' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'social' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'paidsocial' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) like '%paid_social%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) like '%paid-social%') and lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) != 'paid shopping'  THEN 'Paid Social'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid shopping'  THEN 'Paid Shopping'
  WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid other' THEN 'Paid Other'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'display' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium)='display' THEN 'Display'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'email' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%email%' THEN 'Email'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'affiliates' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%affiliate%' OR lower(session_traffic_source_last_click.cross_channel_campaign.Source) LIKE '%affiliate%' THEN 'Affiliates'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.campaign_name) = 'ctv' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%ctv%' OR lower(session_traffic_source_last_click.cross_channel_campaign.Source) LIKE '%ctv%' THEN 'CTV'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic search' or lower(session_traffic_source_last_click.cross_channel_campaign.Source)='google'  or lower(session_traffic_source_last_click.cross_channel_campaign.Source)='chatgpt.com' THEN 'Organic Search'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic social' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organicsocial%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organic-social%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organic_social%' THEN 'Organic Social'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic video' THEN 'Organic Video'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'recurring_order' THEN 'Recharge Recurring Orders'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%podcast%' THEN 'Podcast'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%offline%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%print%' THEN 'Offline Media'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'referral' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%referral%' THEN 'Referral'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'audio' THEN 'Audio'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'mobile push notifications' THEN 'Mobile Push Notifications'
   WHEN session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group = 'Direct' THEN 'Direct'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid video' THEN 'Paid Video'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic shopping' THEN 'Miscellaneous'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'cross-network' THEN 'Cross-network'

   else session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group
END AS Murad_Marketing_Channel,
-- CASE
--    WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) LIKE '%paid%' OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid social' OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'affiliates'  OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'display' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%cpc%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium)= 'social' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%paid-social%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'paidsocial' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%affiliate%' or lower(session_traffic_source_last_click.cross_channel_campaign.Source) = 'affiliate' THEN 'Paid'
--    WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'email' OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'sms' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%sms%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%text%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%offline%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%print%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%email%'  THEN 'CRM'
--    WHEN  lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic search' OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'unassigned'  OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'referral' OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic social' OR lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic video' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organic%' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%referral%' or lower(session_traffic_source_last_click.cross_channel_campaign.Source) = 'google' THEN 'Organic'
--    WHEN  lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic shopping' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) = 'recurring_order' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%tiktokshop%' or lower(session_traffic_source_last_click.cross_channel_campaign.Source) = 'shopify' THEN 'Marketplace' 
--    WHEN  lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'Direct' then 'Direct' 
-- end as Murad_Grouped_Channels,
  session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group,
  session_traffic_source_last_click.cross_channel_campaign.Source,
  session_traffic_source_last_click.cross_channel_campaign.medium,  
  ecommerce.purchase_revenue_in_usd as Total_revenue,ecommerce.tax_value_in_usd as Tax,ecommerce.shipping_value_in_usd as Shipping_cost,ecommerce.transaction_id as Transaction_id
FROM `murad-data-warehouse.analytics_332037127.events_*`
where
event_name = 'purchase'
and
DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) >= '2024-11-01'
  and not (
     (lower(device.category) = 'desktop')
     and (lower(geo.region) IN ('washington', '','istanbul','virginia')
   OR lower(geo.city) in ('ashburn', 'virginia','london', 'england','santa clara', 'california','new york','new york','')
   OR lower(geo.country) in ('china','germany','russia','vietnam','japan','indonesia','netherlands','united arab emirates','colombia','nigeria','spain','philippines','sweden','france','united kingdom','iraq','thailand','chile','india','Bangladesh','Bahrain','Cambodia','Laos'))

--    AND (
--   lower(geo.region) IN ('washington',  'virginia', 'england','')
--   OR lower(geo.city) IN ('istanbul', 'ashburn', 'california', 'london', 'santa clara', 'new york','')
--   OR lower(geo.country) IN ('china', 'germany', 'russia', 'vietnam', 'japan', 'england')
-- )

    -- and
    -- (trim(device.web_info.browser) = 'Chrome' )
    and (trim(device.web_info.browser_version) IN (
    '104.0.0.0',
    '128.0.6613.120',
    '129.0.6668.70',
    '128.0.6613.138',
    '128.0.6613.139',
    '129.0.6668.58',
    '128.0.6613.114',
    '129.0.6668.101',
    '130.0.6723.70',
    '129.0.6668.103',
    '130.0.6723.69',
    '130.0.6723.59',
    '130.0.6723.58',
    '130.0.6723.60',
    '127.0.6533.72',
    '124.0.0.0',
    '131.0.6778.204',
    '128.0.6613.84',
    '118.0.0.0',
    '121.0.6167.85',
    '134.0.6998.178',
    '119.0.6045.105',
    '119.0.6045.123',
    '120.0.6099.199',
    '120.0.6099.109',
    '120.0.6099.224',
    '119.0.6045.199',
    '133.0.0.0',
    '132.0.0.0',
    '131.0.0.0',
    '131.0.6778.204',
    '136.0.7103.114',
    '131.0.6778.70',
    '131.0.6778.69',
    '130.0.0.0',
    '125.0.0.0',
    '134.0.0.0',
    '126.0.6478.114',
    '139.0.0.0',
    '135.0.0.0',
    '119.0.0.0',
    '99.0.4844.51'
)) 
  
   and (lower(trim(session_traffic_source_last_click.cross_channel_campaign.primary_channel_group)) 
   in ('direct','email','unassigned'))
)