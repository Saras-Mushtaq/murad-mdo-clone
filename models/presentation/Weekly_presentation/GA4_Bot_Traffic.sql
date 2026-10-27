{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["murad_marketing_channel"]
) }}

-- GA4_Bot_Traffic (v2): bot sessions per day and Murad channel, from the BigQuery events export.
-- Clean data = Daton minus this table. Output: date, murad_marketing_channel, sessions (INT64), transactions, net_revenue.
--
-- Same as the deployed query:
--   * the two bot segments (2025: desktop + geo + version + channel in Direct/Email/Unassigned;
--     2026+: desktop + version + channel in Direct/Unassigned, NO geo)
--   * the channel CASE (reordered to the UI order), the counting (sessions = session_start events,
--     transactions = distinct transaction_id of purchase events, revenue = purchase - tax - shipping),
--     each event on its own date (America/Los_Angeles), date_spine x channel_list output
-- Different:
--   * the segment conditions are checked over ALL events of a session (the GA4 segments are session-scoped), not on each
--     event row separately. A session that matches counts all of its session_start / purchase events.
--   * 2026+ cookieless hits (no user id / session id) are counted and split Direct/Unassigned by the Daton ratio.
--   * 2025 geo: a blank region/city matches only when BOTH are blank.

WITH sess AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sid,
    MIN(IF(event_name = 'session_start', event_timestamp, NULL)) AS start_ts,
    MIN(event_timestamp) AS first_ts,

    -- each flag below is true if ANY event of the session meets the condition
    LOGICAL_OR(lower(device.category) = 'desktop') AS has_desktop,

    -- 2025 segment: version list
    LOGICAL_OR(trim(device.web_info.browser_version) IN (
      '104.0.0.0','128.0.6613.120','129.0.6668.70','128.0.6613.138','128.0.6613.139','129.0.6668.58',
      '128.0.6613.114','129.0.6668.101','130.0.6723.70','129.0.6668.103','130.0.6723.69','130.0.6723.59',
      '130.0.6723.58','130.0.6723.60','127.0.6533.72','124.0.0.0','131.0.6778.204','128.0.6613.84',
      '118.0.0.0','121.0.6167.85','134.0.6998.178','119.0.6045.105','119.0.6045.123','120.0.6099.199',
      '120.0.6099.109','120.0.6099.224','119.0.6045.199','133.0.0.0','132.0.0.0','131.0.0.0',
      '136.0.7103.114','131.0.6778.70','131.0.6778.69','130.0.0.0','125.0.0.0','134.0.0.0',
      '126.0.6478.114','139.0.0.0','135.0.0.0','119.0.0.0','99.0.4844.51','116.0.0.0','109.0.0.0',
      '111.0.0.0','107.0.0.0','117.0.0.0','142.0.0.0','120.0.0.0','105.0.0.0','112.0.0.0',
      '104.0.5112.81','106.0.5249.119','110.0.0.0','108.0.0.0','103.0.0.0'
    )) AS has_version_2025,

    -- 2025 segment: geo (the 2026 segment has no geo condition)
    LOGICAL_OR(
      lower(geo.region) IN ('washington', 'istanbul', 'virginia')
      OR lower(geo.city) IN ('ashburn', 'virginia', 'london', 'england', 'santa clara', 'california', 'new york')
      OR (lower(geo.region) = '' AND lower(geo.city) = '')
      OR lower(geo.country) IN ('china','germany','russia','vietnam','japan','indonesia','netherlands','united arab emirates','colombia','nigeria','spain','philippines','sweden','france','united kingdom','iraq','thailand','chile','india','bangladesh','bahrain','cambodia','laos','malaysia','nepal','ecuador','venezuela','brazil')
    ) AS has_geo_2025,

    -- 2026 segment: version list
    LOGICAL_OR(trim(device.web_info.browser_version) IN (
      '104.0.0.0','128.0.6613.120','129.0.6668.70','128.0.6613.138','128.0.6613.139','129.0.6668.58',
      '128.0.6613.114','129.0.6668.101','130.0.6723.70','129.0.6668.103','130.0.6723.69','130.0.6723.59',
      '130.0.6723.58','130.0.6723.60','127.0.6533.72','124.0.0.0','131.0.6778.204','128.0.6613.84',
      '118.0.0.0','121.0.6167.85','134.0.6998.178','119.0.6045.105','119.0.6045.123','120.0.6099.199',
      '120.0.6099.109','120.0.6099.224','119.0.6045.199','133.0.0.0','132.0.0.0','131.0.0.0',
      '136.0.7103.114','131.0.6778.70','131.0.6778.69','130.0.0.0','125.0.0.0','134.0.0.0',
      '126.0.6478.114','139.0.0.0','135.0.0.0','119.0.0.0','99.0.4844.51','116.0.0.0','109.0.0.0',
      '111.0.0.0','107.0.0.0','117.0.0.0','142.0.0.0','120.0.0.0','105.0.0.0','112.0.0.0',
      '104.0.5112.81','106.0.5249.119','110.0.0.0','108.0.0.0','103.0.0.0','144.0.7559.132',
      '151.0.7922.173','145.0.0.0','146.0.0.0'
    )) AS has_version_2026,

    -- the session's channel fields, taken from its session_start event
    ARRAY_AGG(session_traffic_source_last_click.cross_channel_campaign IGNORE NULLS ORDER BY IF(event_name = 'session_start', 0, 1), event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS cc,

    -- the session's session_start and purchase events, each with its own date, as in the deployed query
    ARRAY_AGG(
      IF(event_name IN ('session_start', 'purchase'),
         STRUCT(
           DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) AS d,
           event_name AS name,
           ecommerce.transaction_id AS txn,
           ecommerce.purchase_revenue_in_usd - ecommerce.tax_value_in_usd - ecommerce.shipping_value_in_usd AS rev
         ),
         NULL)
      IGNORE NULLS
    ) AS ev
  FROM `murad-data-warehouse.analytics_332037127.events_*`
  WHERE _TABLE_SUFFIX >= '20241031'
  GROUP BY 1, 2
  HAVING sid IS NOT NULL AND user_pseudo_id IS NOT NULL
),

seg AS (
  SELECT
    *,
    DATE(DATETIME(TIMESTAMP_MICROS(COALESCE(start_ts, first_ts)), "America/Los_Angeles")) AS session_date,
    NULLIF(NULLIF(lower(trim(cc.primary_channel_group)), ''), '(not set)') AS primary_grp   -- blank / '(not set)' are treated like NULL
  FROM sess
  WHERE has_desktop   -- sessions without a session_start stay in: they add no sessions, but their purchases count (as in the UI)
),

bot_sessions AS (
  SELECT
    CASE
      WHEN lower(cc.medium) LIKE '%infomercial%' THEN 'Infomercial'
      WHEN (lower(cc.Default_Channel_group) = 'paid video' OR lower(cc.campaign_name) LIKE '%yout%' OR lower(cc.campaign_name) LIKE '%youtube%' OR lower(cc.medium) LIKE '%paid_video%') AND lower(cc.medium) <> 'email' THEN 'Paid Video'
      WHEN lower(cc.Default_Channel_group) = 'paid search' OR lower(cc.medium) LIKE '%cpc%' THEN 'Paid Search'
      WHEN lower(cc.Default_Channel_group) = 'sms' OR lower(cc.medium) LIKE '%sms%' OR lower(cc.medium) LIKE '%text%' OR lower(cc.campaign_name) = '082026_excess sale' OR lower(cc.campaign_name) = '082326_excess sale' THEN 'SMS'
      WHEN lower(cc.medium) = 'recurring_order' THEN 'Recharge Recurring Orders'
      WHEN lower(cc.medium) LIKE '%tiktokshop%' THEN 'TikTok Shop'
      WHEN lower(cc.Source) LIKE '%shopify%' AND (lower(cc.medium) LIKE '%facebook%' OR lower(cc.medium) = 'web' OR lower(cc.medium) = 'shop' OR lower(cc.Source) = 'shopify' OR lower(cc.Source) = 'shop_app') THEN 'FB IG Shop'
      WHEN (lower(cc.Default_Channel_group) = 'paid social' OR lower(cc.medium) = 'social' OR lower(cc.medium) = 'paidsocial' OR lower(cc.medium) LIKE '%paid_social%' OR lower(cc.medium) LIKE '%paid-social%') THEN 'Paid Social'
      WHEN lower(cc.Default_Channel_group) = 'display' OR lower(cc.medium) = 'display' THEN 'Display'
      WHEN lower(cc.Default_Channel_group) = 'email' OR lower(cc.medium) LIKE '%email%' THEN 'Email'
      WHEN lower(cc.Default_Channel_group) = 'affiliates' OR lower(cc.medium) LIKE '%affiliate%' OR lower(cc.Source) LIKE '%affiliate%' THEN 'Affiliates'
      WHEN lower(cc.campaign_name) LIKE '%ctv%' OR lower(cc.medium) LIKE '%ctv%' OR lower(cc.Source) LIKE '%ctv%' THEN 'CTV'
      WHEN lower(cc.Default_Channel_group) = 'organic search' OR lower(cc.Source) = 'google' OR lower(cc.Source) = 'chatgpt.com' THEN 'Organic Search'
      WHEN lower(cc.Default_Channel_group) = 'organic social' OR lower(cc.medium) LIKE '%organicsocial%' OR lower(cc.medium) LIKE '%organic-social%' OR lower(cc.medium) LIKE '%organic_social%' THEN 'Organic Social'
      WHEN lower(cc.Default_Channel_group) = 'organic video' THEN 'Organic Video'
      WHEN lower(cc.medium) LIKE '%podcast%' THEN 'Podcast'
      WHEN lower(cc.medium) LIKE '%offline%' OR lower(cc.medium) LIKE '%print%' THEN 'Offline Media'
      WHEN lower(cc.Default_Channel_group) = 'referral' OR lower(cc.medium) LIKE '%referral%' OR lower(cc.Source) = 'blog' THEN 'Referral'
      WHEN lower(cc.Default_Channel_group) = 'paid other' THEN 'Paid Other'
      WHEN lower(cc.Default_Channel_group) = 'audio' THEN 'Audio'
      WHEN lower(cc.Default_Channel_group) = 'mobile push notifications' THEN 'Mobile Push Notifications'
      WHEN cc.Default_Channel_group = 'Direct' THEN 'Direct'
      WHEN lower(cc.Default_Channel_group) = 'paid shopping' THEN 'Paid Shopping'
      WHEN lower(cc.Default_Channel_group) = 'organic shopping' THEN 'Miscellaneous'
      WHEN lower(cc.Default_Channel_group) = 'cross-network' THEN 'Cross-network'
      ELSE COALESCE(NULLIF(NULLIF(cc.Default_Channel_group, ''), '(not set)'), 'Direct')
    END AS channel,
    ev
  FROM seg
  WHERE session_date >= '2024-11-01'
    AND (
      -- 2025 segment (sessions starting before 2026-01-01):
      --   desktop AND geo AND version (2025 list) AND channel in (Direct, Email, Unassigned)
      (
        session_date < '2026-01-01'
        AND has_version_2025
        AND has_geo_2025
        AND primary_grp IN ('direct', 'email', 'unassigned')
      )
      OR
      -- 2026 segment (sessions starting from 2026-01-01):
      --   desktop AND version (2026 list) AND channel in (Direct, Unassigned). No geo condition.
      (
        session_date >= '2026-01-01'
        AND has_version_2026
        AND (primary_grp IN ('direct', 'unassigned') OR primary_grp IS NULL)
      )
    )
),

-- 2026+ cookieless hits: no user id and no session id, so they cannot be grouped into sessions.
-- Counted per session_start row, then split Direct/Unassigned below.
cookieless AS (
  SELECT
    'UNMAPPED' AS channel,
    DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) AS date,
    'session_start' AS name,
    CAST(NULL AS STRING) AS txn,
    CAST(NULL AS FLOAT64) AS rev
  FROM `murad-data-warehouse.analytics_332037127.events_*`
  WHERE _TABLE_SUFFIX >= '20251231'
    AND event_name = 'session_start'
    AND user_pseudo_id IS NULL
    AND DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), "America/Los_Angeles")) >= '2026-01-01'
    AND lower(device.category) = 'desktop'
    AND trim(device.web_info.browser_version) IN (
      '104.0.0.0','128.0.6613.120','129.0.6668.70','128.0.6613.138','128.0.6613.139','129.0.6668.58',
      '128.0.6613.114','129.0.6668.101','130.0.6723.70','129.0.6668.103','130.0.6723.69','130.0.6723.59',
      '130.0.6723.58','130.0.6723.60','127.0.6533.72','124.0.0.0','131.0.6778.204','128.0.6613.84',
      '118.0.0.0','121.0.6167.85','134.0.6998.178','119.0.6045.105','119.0.6045.123','120.0.6099.199',
      '120.0.6099.109','120.0.6099.224','119.0.6045.199','133.0.0.0','132.0.0.0','131.0.0.0',
      '136.0.7103.114','131.0.6778.70','131.0.6778.69','130.0.0.0','125.0.0.0','134.0.0.0',
      '126.0.6478.114','139.0.0.0','135.0.0.0','119.0.0.0','99.0.4844.51','116.0.0.0','109.0.0.0',
      '111.0.0.0','107.0.0.0','117.0.0.0','142.0.0.0','120.0.0.0','105.0.0.0','112.0.0.0',
      '104.0.5112.81','106.0.5249.119','110.0.0.0','108.0.0.0','103.0.0.0','144.0.7559.132',
      '151.0.7922.173','145.0.0.0','146.0.0.0'
    )
    AND NULLIF(NULLIF(lower(trim(session_traffic_source_last_click.cross_channel_campaign.primary_channel_group)), ''), '(not set)') IS NULL
),

bot_events AS (
  SELECT b.channel, e.d AS date, e.name, e.txn, e.rev
  FROM bot_sessions b, UNNEST(b.ev) AS e
  UNION ALL
  SELECT channel, date, name, txn, rev FROM cookieless
),

-- same counting as the deployed `agg`: event_name is applied here, not in the row filter
metrics AS (
  SELECT
    date,
    channel,
    COUNTIF(name = 'session_start') AS sessions,
    COUNT(DISTINCT IF(name = 'purchase', txn, NULL)) AS transactions,
    IFNULL(SUM(IF(name = 'purchase', rev, NULL)), 0) AS net_revenue
  FROM bot_events
  GROUP BY 1, 2
),

-- daily share of Unassigned within Direct + Unassigned in the raw (bots included) Daton data
ratio AS (
  SELECT
    date,
    SAFE_DIVIDE(
      SUM(IF(Murad_Marketing_Channel = 'Unassigned', Sessions, 0)),
      SUM(IF(Murad_Marketing_Channel IN ('Direct', 'Unassigned'), Sessions, 0))
    ) AS u_share
  FROM `murad-data-warehouse.prod_presentation.GA4_Daton`
  GROUP BY date
),

final_metrics AS (
  SELECT date, channel, sessions, transactions, net_revenue
  FROM metrics
  WHERE channel != 'UNMAPPED'

  UNION ALL

  -- cookieless sessions: Unassigned gets the rounded share, Direct the remainder (whole sessions, total preserved)
  SELECT
    m.date,
    'Direct',
    m.sessions - CAST(ROUND(m.sessions * IFNULL(r.u_share, 0)) AS INT64),
    0,
    CAST(0 AS FLOAT64)
  FROM metrics m
  LEFT JOIN ratio r USING (date)
  WHERE m.channel = 'UNMAPPED'

  UNION ALL

  SELECT
    m.date,
    'Unassigned',
    CAST(ROUND(m.sessions * IFNULL(r.u_share, 0)) AS INT64),
    0,
    CAST(0 AS FLOAT64)
  FROM metrics m
  LEFT JOIN ratio r USING (date)
  WHERE m.channel = 'UNMAPPED'
),

agg AS (
  SELECT
    date,
    channel,
    SUM(sessions) AS sessions,
    SUM(transactions) AS transactions,
    SUM(net_revenue) AS net_revenue
  FROM final_metrics
  GROUP BY 1, 2
),

date_spine AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2025-01-01', current_date())) AS date
),

channel_list AS (
  SELECT channel FROM UNNEST([
    'Infomercial','Paid Video','Paid Search','SMS','Recharge Recurring Orders','TikTok Shop','FB IG Shop',
    'Paid Social','Display','Email','Affiliates','CTV','Organic Search','Organic Social','Organic Video',
    'Podcast','Offline Media','Referral','Paid Other','Audio','Mobile Push Notifications','Direct',
    'Paid Shopping','Miscellaneous','Cross-network','Unassigned','AI Assistant'
  ]) AS channel
  UNION DISTINCT
  SELECT DISTINCT channel FROM agg WHERE channel IS NOT NULL
)

SELECT
  d.date,
  c.channel AS murad_marketing_channel,
  COALESCE(a.sessions, 0) AS sessions,
  COALESCE(a.transactions, 0) AS transactions,
  COALESCE(a.net_revenue, 0) AS net_revenue
FROM date_spine d
CROSS JOIN channel_list c
LEFT JOIN agg a
  ON d.date = a.date
  AND c.channel = a.channel

