{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["Murad_Marketing_Channel"]
) }}

select Murad_Marketing_Channel,
date(start_date) date,
transactionid Transactions, row_num,

-- sessions only from non-transaction rows (transaction rows carry sessions already counted on '(not set)' rows)
sum(case when transactionId is null or transactionId = '(not set)'
         then coalesce(cast(sessions as float64), cast(sessions_in as float64))
         else 0 end) Sessions,

sum(coalesce(cast(calcMetricnet_revenue as float64),
             cast(calcMetricnet_revenue_in as float64),
             cast(calcMetricnet_revenue_nu as float64), 0)) Net_Revenue
from
(
  select *,
  -- one row per transaction id; non-transaction rows keep row_num = 1
  CASE
    WHEN transactionId = '(not set)' OR transactionId IS NULL THEN 1
    ELSE ROW_NUMBER() OVER (
      PARTITION BY transactionId
      ORDER BY
        CASE
          WHEN sessionMedium = '(data not available)' THEN 4   -- placeholder row GA4 attaches to the order; never prefer it
          WHEN sessionDefaultChannelGroup NOT IN ('Unassigned', 'Direct') THEN 1
          WHEN sessionDefaultChannelGroup = 'Direct' THEN 2
          WHEN sessionDefaultChannelGroup = 'Unassigned' THEN 3
          ELSE 4
        END ASC,
        sessionMedium, sessionSource, sessionDefaultChannelGroup   -- deterministic tiebreak
    )
  END AS row_num
  from
  (select *,
    -- rule order follows the UI's custom channel group sequence; campaign-name rules unavailable in this table
    CASE
      WHEN lower(sessionMedium) LIKE '%infomercial%' THEN 'Infomercial'
      WHEN (lower(sessionDefaultChannelGroup) = 'paid video' OR lower(sessionMedium) LIKE '%paid_video%')
           AND lower(sessionMedium) <> 'email' THEN 'Paid Video'
      WHEN lower(sessionDefaultChannelGroup) = 'paid search' OR lower(sessionMedium) LIKE '%cpc%' THEN 'Paid Search'
      WHEN lower(sessionDefaultChannelGroup) = 'sms' OR lower(sessionMedium) LIKE '%sms%' OR lower(sessionMedium) LIKE '%text%' THEN 'SMS'
      WHEN lower(sessionMedium) = 'recurring_order' THEN 'Recharge Recurring Orders'
      WHEN lower(sessionMedium) LIKE '%tiktokshop%' THEN 'TikTok Shop'
      WHEN lower(sessionSource) LIKE '%shopify%'
           AND (lower(sessionMedium) LIKE '%facebook%' OR lower(sessionMedium) = 'web' OR lower(sessionMedium) = 'shop'
                OR lower(sessionSource) = 'shopify' OR lower(sessionSource) = 'shop_app') THEN 'FB IG Shop'
      WHEN (lower(sessionDefaultChannelGroup) = 'paid social' OR lower(sessionMedium) = 'social' OR lower(sessionMedium) = 'paidsocial'
            OR lower(sessionMedium) LIKE '%paid_social%' OR lower(sessionMedium) LIKE '%paid-social%') THEN 'Paid Social'
      WHEN lower(sessionDefaultChannelGroup) = 'display' OR lower(sessionMedium) = 'display' THEN 'Display'
      WHEN lower(sessionDefaultChannelGroup) = 'email' OR lower(sessionMedium) LIKE '%email%' THEN 'Email'
      WHEN lower(sessionDefaultChannelGroup) = 'affiliates' OR lower(sessionMedium) LIKE '%affiliate%' OR lower(sessionSource) LIKE '%affiliate%' THEN 'Affiliates'
      WHEN lower(sessionMedium) LIKE '%ctv%' OR lower(sessionSource) LIKE '%ctv%' THEN 'CTV'
      WHEN lower(sessionDefaultChannelGroup) = 'organic search' OR lower(sessionSource) = 'google' OR lower(sessionSource) = 'chatgpt.com' THEN 'Organic Search'
      WHEN lower(sessionDefaultChannelGroup) = 'organic social' OR lower(sessionMedium) LIKE '%organicsocial%'
           OR lower(sessionMedium) LIKE '%organic-social%' OR lower(sessionMedium) LIKE '%organic_social%' THEN 'Organic Social'
      WHEN lower(sessionDefaultChannelGroup) = 'organic video' THEN 'Organic Video'
      WHEN lower(sessionMedium) LIKE '%podcast%' THEN 'Podcast'
      WHEN lower(sessionMedium) LIKE '%offline%' OR lower(sessionMedium) LIKE '%print%' THEN 'Offline Media'
      WHEN lower(sessionDefaultChannelGroup) = 'referral' OR lower(sessionMedium) LIKE '%referral%' OR lower(sessionSource) = 'blog' THEN 'Referral'
      WHEN lower(sessionDefaultChannelGroup) = 'paid other' THEN 'Paid Other'
      WHEN lower(sessionDefaultChannelGroup) = 'audio' THEN 'Audio'
      WHEN lower(sessionDefaultChannelGroup) = 'mobile push notifications' THEN 'Mobile Push Notifications'
      WHEN sessionDefaultChannelGroup = 'Direct' THEN 'Direct'
      WHEN lower(sessionDefaultChannelGroup) = 'paid shopping' THEN 'Paid Shopping'
      WHEN lower(sessionDefaultChannelGroup) = 'organic shopping' THEN 'Miscellaneous'
      WHEN lower(sessionDefaultChannelGroup) = 'cross-network' THEN 'Cross-network'
      ELSE sessionDefaultChannelGroup
    END AS Murad_Marketing_Channel
   from murad-data-warehouse.BigQuery.ga4_332037127_Daton_GA4
   qualify row_number() over (partition by start_date, sessionDefaultChannelGroup, sessionMedium, sessionsource, transactionid order by _daton_batch_runtime desc) = 1
  )
)
where row_num = 1
  -- drop blank transactionId rows (a separate, partial copy of the session data)
  and (transactionId is null or transactionId != '')
group by 1, 2, 3, 4