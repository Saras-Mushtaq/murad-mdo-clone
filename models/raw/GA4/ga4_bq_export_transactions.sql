{{ config(enabled = False) }}

{{ config(
   materialized='incremental',
   incremental_strategy='merge',
   unique_key='transaction_id'

) }}



select
DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) date,
event_name,
CASE
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid search' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%cpc%' THEN 'Paid Search'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'sms' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%sms%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%text%' THEN 'SMS'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%tiktokshop%' THEN 'TikTok Shop'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Source) = 'shopify' and lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%facebook%'  THEN 'FB IG Shop'
   WHEN (lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid social' or lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%social%') and lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) != 'paid shopping'  THEN 'Paid Social'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid shopping'  THEN 'Paid Shopping'
  WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid other' THEN 'Paid Other'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'display' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%display%' THEN 'Display'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'email' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%email%' THEN 'Email'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'affiliates' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%affiliate%' OR lower(session_traffic_source_last_click.cross_channel_campaign.Source) LIKE '%affiliate%' THEN 'Affiliates'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.campaign_name) = 'ctv' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%ctv%' OR lower(session_traffic_source_last_click.cross_channel_campaign.Source) LIKE '%ctv%' THEN 'CTV'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic search' THEN 'Organic Search'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic social' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organicsocial%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organic-social%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%organic_social%' THEN 'Organic Social'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic video' THEN 'Organic Video'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%recurring_order%' THEN 'Recharge Recurring Orders'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%podcast%' THEN 'Podcast'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%offline%' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%print%' THEN 'Offline Media'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'referral' OR lower(session_traffic_source_last_click.cross_channel_campaign.medium) LIKE '%referral%' THEN 'Referral'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'audio' THEN 'Audio'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'mobile push notifications' THEN 'Mobile Push Notifications'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'direct' THEN 'Direct'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'paid video' THEN 'Paid Video'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'organic shopping' THEN 'Organic Shopping'
   WHEN lower(session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group) = 'cross-network' THEN 'Cross-network'
   else session_traffic_source_last_click.cross_channel_campaign.Default_Channel_group
END AS Murad_Marketing_Channel,
-- COUNT(*) AS event_count,
  event_bundle_sequence_id,
  ecommerce.purchase_revenue_in_usd,ecommerce.tax_value_in_usd,ecommerce.shipping_value_in_usd,ecommerce.transaction_id
FROM `murad-data-warehouse.analytics_332037127.events_*`
where
event_name = 'purchase'
and
DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) > '2024-11-01'
  and not (
    (trim(device.web_info.browser) = 'Chrome' )
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
    '118.0.0.0'
)) and (lower(geo.region) IN ('washington', '(not set)')
   OR lower(geo.city) in ('ashburn', 'virginia'))
   and (lower(device.category) = 'desktop')
   and (lower(trim(session_traffic_source_last_click.cross_channel_campaign.primary_channel_group)) in ('direct','email'))
)

{% if is_incremental() %}
  AND DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) >= (
    SELECT max(date)
 - {{ var('ga_bq_export_lookback', 0) }} day
    FROM {{ this }}
  )
{% endif %}

