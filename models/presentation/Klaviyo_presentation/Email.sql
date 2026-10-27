{{ config(
    materialized='table',
    partition_by={
      "field": "event_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["Type", "id", "name"]
) }}

With names as(
select distinct * from(select DISTINCT id Ids, attributes.name name,'C' as Type,
CASE
  when id='01KECZGENDQRGQ78H6Z3TTCHZ8' then '2026-01-11' -- naming is wrong for this campaign
   when id='01JEQ38Y77G7FYJHPYVBJX2S85' then '2025-01-29'
   when id='01KJ91HF6W3WMJQZAYNDMTCR02' then '2026-03-02'
   when id='01KHXXCCFM8FH23V6W6BDR3F6R' then '2026-03-03'
   when id='01KS3TY4XP5YPDEP3VFT05WC4J' then '2026-05-24'
   when id='01KQG8C5RJT6PS51HQ7GV7Q04Z' then '2026-05-18'
   when id='01KRCN3BSAGN2WTKBR6B22TQF9' then '2026-05-24'
  WHEN REGEXP_CONTAINS(SPLIT(attributes.name, '_')[OFFSET(0)], r'^\d{6}$') THEN
    CONCAT(
      '20',
      SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 5, 2), '-',
      SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 1, 2), '-',
      SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 3, 2)
    )
  ELSE NULL
END as send_date1 FROM
  murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_campaigns
LEFT JOIN
  UNNEST(attributes) attributes )
union all
(select DISTINCT id, attributes.name,'F' as Type,cast(null as string) as send_date1  FROM
  murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_flows
LEFT JOIN
  UNNEST(attributes) attributes 
)
-- union all
-- (select DISTINCT id Ids, attributes.name name,'C' as Type,
-- CASE
--   WHEN REGEXP_CONTAINS(SPLIT(attributes.name, '_')[OFFSET(0)], r'^\d{6}$') THEN
--     coalesce(CONCAT(
--       '20',
--       SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 5, 2), '-',
--       SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 1, 2), '-',
--       SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 3, 2)
--     ),null)
--   ELSE NULL
-- END as send_date1 FROM
--   murad-data-warehouse.BigQuery.Klaviyo_Integration_US_campaigns
-- LEFT JOIN
--   UNNEST(attributes) attributes )
-- union all
-- (select DISTINCT id, attributes.name,'F' as Type,cast(null as string) as send_date1  FROM
--   murad-data-warehouse.BigQuery.Klaviyo_Integration_US_flows
-- LEFT JOIN
--   UNNEST(attributes) attributes )
),
matrix_pre as(
  (SELECT
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS string) AS events,
  0 as Revenue,
  CAST(event_properties.flow AS string) AS Flow_id,
  CAST(event_properties.message AS string) AS Campaign_id,
  CAST(event_properties.CampaignName AS string) AS message_name,
  DATE(DATETIME(datetime, "America/Los_Angeles")) event_date,
  date(DATETIME(TIMESTAMP_SECONDS(CAST(SPLIT(_cohortmessage_send_cohort, ':')[OFFSET(0)] AS INT64)), "America/Los_Angeles")) send_date,
  'R' Event
FROM
  murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_received_email a
LEFT JOIN
  UNNEST(attributes) attributes
LEFT JOIN
  UNNEST(attributes.event_properties) event_properties
LEFT JOIN
  UNNEST(links) links
LEFT JOIN
  UNNEST(relationships) relationships
LEFT JOIN
  UNNEST(relationships.profile) profile
LEFT JOIN
  UNNEST(profile.data) DATA
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY id ORDER BY _daton_batch_runtime DESC) = 1)
union all
(
 SELECT
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS string) AS events,
  0 as Revenue,
  CAST(event_properties.flow AS string) AS Flow_id,
  CAST(event_properties.message AS string) AS Campaign_id,
CAST(event_properties.CampaignName AS string) AS message_name,
  date(DATETIME(datetime, "America/Los_Angeles")) event_date,
  date(DATETIME(TIMESTAMP_SECONDS(CAST(SPLIT(_cohortmessage_send_cohort, ':')[OFFSET(0)] AS INT64)), "America/Los_Angeles")) send_date,
  'C' Event
FROM
  murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_clicked_email a
LEFT JOIN
  UNNEST(attributes) attributes
LEFT JOIN
  UNNEST(attributes.event_properties) event_properties
LEFT JOIN
  UNNEST(links) links
LEFT JOIN
  UNNEST(relationships) relationships
LEFT JOIN
  UNNEST(relationships.profile) profile
LEFT JOIN
  UNNEST(profile.data) DATA
where botclick=false
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY id ORDER BY _daton_batch_runtime DESC) = 1 
)
Union all
(
 SELECT
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS string) AS events,
  0 as Revenue,
  CAST(event_properties.flow AS string) AS Flow_id,
  CAST(event_properties.message AS string) AS Campaign_id,
CAST(event_properties.CampaignName AS string) AS message_name,
  date(DATETIME(datetime, "America/Los_Angeles")) event_date,
  date(DATETIME(TIMESTAMP_SECONDS(CAST(SPLIT(_cohortmessage_send_cohort, ':')[OFFSET(0)] AS INT64)), "America/Los_Angeles")) send_date,
  'O' Event
FROM
  murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_opened_email a
LEFT JOIN
  UNNEST(attributes) attributes
LEFT JOIN
  UNNEST(attributes.event_properties) event_properties
LEFT JOIN
  UNNEST(links) links
LEFT JOIN
  UNNEST(relationships) relationships
LEFT JOIN
  UNNEST(relationships.profile) profile
LEFT JOIN
  UNNEST(profile.data) DATA
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY id ORDER BY _daton_batch_runtime DESC) = 1 
)
Union all(
      SELECT
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS string) AS events,
  0 as Revenue,
  CAST(null AS string) AS Flow_id,
  CAST(null AS string) AS Campaign_id,
CAST(null AS string) AS message_name,
  date(DATETIME(datetime, "America/Los_Angeles")) event_date,
  date(null) send_date,
  'Sub' Event
FROM
  murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_subscribed_to_email_marketing a
LEFT JOIN
  UNNEST(attributes) attributes
LEFT JOIN
  UNNEST(attributes.event_properties) event_properties
LEFT JOIN
  UNNEST(links) links
LEFT JOIN
  UNNEST(relationships) relationships
LEFT JOIN
  UNNEST(relationships.profile) profile
LEFT JOIN
  UNNEST(profile.data) DATA
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY id ORDER BY _daton_batch_runtime DESC) = 1 
)
),
orders as(
  select b.id id,b.events as events,b.Revenue as Revenue,b.Flow_id as Flow_id,b.Campaign_id as Campaign_id,a.message_name,b.event_date as event_date,coalesce(a.send_date,b.send_date) as send_date,b.Event as Event from ((
   select * from ( SELECT 
COALESCE(a.id, 'N/A') AS id,
  CAST(extra.id  AS string) AS events,
  CAST(event_properties.value AS numeric)  as Revenue,
  CAST(fdata.id AS string) AS Flow_id,
  coalesce(CAST(cdata.id AS string),CAST(fmdata.id AS string)) AS Campaign_id,
  CAST(null AS string) As message_name,
  DATE(DATETIME(datetime, "America/Los_Angeles")) event_date,
  date(null) send_date,
  'Or' Event,
  aed.id event_id
 FROM
   murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_placed_order a 
 LEFT JOIN 
   UNNEST(attributes) attributes 
 LEFT JOIN 
   UNNEST(attributes.event_properties) event_properties 
 LEFT JOIN 
   UNNEST(event_properties.extra) extra 
 LEFT JOIN 
   UNNEST(relationships) r 
 left join 
  unnest(r.attributedevent) ae
left join
  unnest(ae.data) aed
 left join 
   UNNEST(r.flow) f 
 left join 
   UNNEST(f.data) fdata
 left join 
   UNNEST(r.campaign) c 
 left join 
   UNNEST(c.data) cdata
  left join 
   UNNEST(r.flowmessage) fm 
 left join 
   UNNEST(fm.data) fmdata
 QUALIFY DENSE_RANK() OVER(PARTITION BY a.id ORDER BY a._daton_batch_runtime DESC) = 1)
 where coalesce(Flow_id,Campaign_id) in (select distinct coalesce(Flow_id,Campaign_id) from matrix_pre ) and id not in (select id from {{ref("sms_flow_camp")}} )
) b left join (select id,min(send_date) send_date,message_name from matrix_PRE group by 1,3) a on event_id=a.id)
),
matrix AS(
 SELECT * FROM MATRIX_PRE
 UNION ALL
 SELECT * FROM ORDERS
)
select * EXCEPT ( send_date1,ids,send_date,id3,sndate),coalesce(SAFE_CAST(send_date1 AS DATE),send_date,sndate) as send_date from 
-- names n 
matrix m 
left join 
  -- matrix m 
  
(select * from names WHERE name NOT IN (
    '122825_Use your FSA #1 Launch',
    '021426_20% Off Sitewide (BACK-UP) (US)',
    '012826_Lipid Cleansing Balm #7 Upsell',
    '021626_20% Off Sitewide Ends Tonight AM (BACK-UP)',
    '021626_20% Off Sitewide Last Chance PM (BACK-UP) (US)',
    '021626_20% Off Sitewide Ends Tonight (BACK-UP) AM (US)',
    'Campaign Feb 24, 2026, 11:14 AM (clone) (clone)',
    '030226_Choose Your Full-Size Toner with $85 #4 (US)',
    '030326_20% Off Serums & Treatments (US)',
    '031126_Rapid Dark Spot Correcting Serum #5 (US)',
    '031326_Loyalty Exclusive: Oil Drops PR Box #2 Reminder (US)',
    '032626_Friends & Family: 25% off Sitewide PM: Final Hours (US)',
    '032626_Friends & Family: 25% off Sitewide AM: Ends Tonight (US)',
    '032726_CRM Exclusive: 20% off (US)',
    '040226_Free Vita-C Serum Deluxe Travel with $85',
    '032926_Evergreen: Find your moisturizer (US)',
    '040926_Earth Day: Up to XX% Off on Excess (BACKUP)',
    '041626_Earth Day: Up to XX% Off on Excess (BACKUP) Last Chance',
    '041226_Free Vita-C Serum Deluxe Travel with $85',
    '051926_1000 Points on Excess - CHR Cream',
    '052226_Memorial Day Email 2',
    '052926_Free Trio with $100',
    '060526_Never forget your first #6 Lifestyle focus',
    'WELCOME FLOW 15% Off_SD 2026',
    'SESSION ABANDONMENT_SD 2026',
    'BROWSE ABANDONMENT_SD 2026',
    'CART ABANDONMENT_SD 2026',
    'Checkout Abandonment_Infomercial',
    'Subscribe & Save Upsell Email',
    'WELCOME FLOW 2026 [SD]',
    'NEW WELCOME 2026 [SD]',
'SESSION ABANDONMENT 2026 [SD]',
'BROWSE ABANDONMENT 2026 [SD]',
'CHECKOUT ABANDONMENT_SD 2026',
'CHECKOUT ABANDONMENT 2026 [SD]',
'CART ABANDONMENT 2026 [SD]',
'SKIN QUIZ 2026 [SD]',
'Welcome Flow_Infomercial',
'Post-Purchase_Infomercial',
'091626_Holiday Kits',
'100926_AI Skin Quiz',
'101326_Choose Your Duo with $125',
'TBD_New Rewards Available',
'102026_Black Friday Preview: 30% Off Sitewide',
'102026_Black Friday Preview: 30% Off Sitewide VIP',
'102226_Black Friday Preview: 30% Off Sitewide',
'102126_Black Friday Preview: 30% Off Sitewide'

)
AND NOT (
    name = '021326_20% Off Sitewide (BACK-UP) (US)'
    AND ids = '01KG56WN7BVHNSKT2KDX3Q37PA'
)) n 
on n.ids=coalesce(Flow_id,Campaign_id)
left join
(select distinct Flow_id id3,min(send_date) sndate from matrix group by 1) d on n.ids=d.id3 where event_date>='2025-01-01' 