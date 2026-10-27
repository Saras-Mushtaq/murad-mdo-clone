With names as(
select distinct * from(

select DISTINCT id Ids, attributes.name name,'C' as Type,
CASE
  WHEN REGEXP_CONTAINS(SPLIT(attributes.name, '_')[OFFSET(0)], r'^\d{6}$') THEN
    coalesce(CONCAT(
      '20',
      SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 5, 2), '-',
      SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 1, 2), '-',
      SUBSTRING(SPLIT(attributes.name, '_')[OFFSET(0)], 3, 2)
    ),null)
  ELSE NULL
END as send_date1 FROM
  murad-data-warehouse.BigQuery.Klaviyo_Integration_US_campaigns
LEFT JOIN
  UNNEST(attributes) attributes )
union all
(select DISTINCT id, attributes.name,'F' as Type,cast(null as string) as send_date1  FROM
  murad-data-warehouse.BigQuery.Klaviyo_Integration_US_flows
LEFT JOIN
  UNNEST(attributes) attributes )
),
matrix as(
  (SELECT
COALESCE(a.id, 'N/A') AS id,
  CAST(coalesce(data.id,data2.id) AS string) AS events,
  0 as Revenue,
  CAST(event_properties.flow AS string) AS Flow_id,
  CAST(event_properties.message AS string) AS Campaign_id,
  date(TIMESTAMP_SUB(CAST(CASE
        WHEN LENGTH(datetime) = 17 THEN REPLACE(datetime,"Z",":00+00:00")
        WHEN LENGTH(datetime) = 20 THEN REPLACE(datetime,"Z","+00:00")
        ELSE datetime
    END
      AS timestamp), INTERVAL 8 hour)) event_date,
  date(DATETIME(TIMESTAMP_SECONDS(CAST(SPLIT(cohort_message_send_cohort, ':')[OFFSET(0)] AS INT64)), "America/Los_Angeles")) send_date,
    'R' Event

FROM
  murad-data-warehouse.BigQuery.Klaviyo_Integration_US_received_email a
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
left join
  UNNEST(relationships.profiles) profiles
LEFT JOIN
  UNNEST(profile.data) DATA
LEFT JOIN
  UNNEST(profiles.data) DATA2
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY a.id ORDER BY _daton_batch_runtime DESC) = 1
)
union all
(
 SELECT
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS string) AS events,
  0 as Revenue,
  CAST(event_properties.flow AS string) AS Flow_id,
  CAST(event_properties.message AS string) AS Campaign_id,
 date(TIMESTAMP_SUB(CAST(CASE
        WHEN LENGTH(datetime) = 17 THEN REPLACE(datetime,"Z",":00+00:00")
        WHEN LENGTH(datetime) = 20 THEN REPLACE(datetime,"Z","+00:00")
        ELSE datetime
    END
      AS timestamp), INTERVAL 8 hour)) event_date,
  date(DATETIME(TIMESTAMP_SECONDS(CAST(SPLIT(_cohortmessage_send_cohort, ':')[OFFSET(0)] AS INT64)), "America/Los_Angeles")) send_date,
  'C' Event
FROM
  murad-data-warehouse.BigQuery.Klaviyo_Integration_US_clicked_email a
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
  date(TIMESTAMP_SUB(CAST(CASE
        WHEN LENGTH(datetime) = 17 THEN REPLACE(datetime,"Z",":00+00:00")
        WHEN LENGTH(datetime) = 20 THEN REPLACE(datetime,"Z","+00:00")
        ELSE datetime
    END
      AS timestamp), INTERVAL 8 hour)) event_date,
  date(DATETIME(TIMESTAMP_SECONDS(CAST(SPLIT(event_properties.cohort_message_send_cohort, ':')[OFFSET(0)] AS INT64)), "America/Los_Angeles")) send_date,
  'O' Event
FROM
  murad-data-warehouse.BigQuery.Klaviyo_Integration_US_opened_email a
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
union all
(
   select * from ( SELECT 
 COALESCE(a.id, 'N/A') AS id, 
 CAST(extra.id AS string) AS events, 
 CAST(event_properties.value AS numeric) AS Revenue, 
  CAST(attribution.flow AS string) AS Flow_id, 
 CAST(attribution.message AS string) AS Campaign_id, 
   date(TIMESTAMP_SUB(CAST(CASE
        WHEN LENGTH(datetime) = 17 THEN REPLACE(datetime,"Z",":00+00:00")
        WHEN LENGTH(datetime) = 20 THEN REPLACE(datetime,"Z","+00:00")
        ELSE datetime
    END
      AS timestamp), INTERVAL 8 hour)) Event_date, 
DATETIME(
  TIMESTAMP_SECONDS(cast(send_ts as int64)),
  'America/Los_Angeles'
) send_date, 
'Or' Event,

 FROM 
   murad-data-warehouse.BigQuery.Klaviyo_Integration_US_placed_order a 
 LEFT JOIN 
   UNNEST(attributes) attributes 
 LEFT JOIN 
   UNNEST(attributes.event_properties) event_properties 
 LEFT JOIN 
   UNNEST(event_properties.extra) extra 
 LEFT JOIN 
   UNNEST(event_properties.attribution) attribution 
 LEFT JOIN 
   UNNEST(links) links 
 LEFT JOIN 
   UNNEST(relationships) relationships 
 LEFT JOIN 
   UNNEST(relationships.profile) profile 
 LEFT JOIN 
   UNNEST(profile.data) DATA 
 QUALIFY DENSE_RANK() OVER(PARTITION BY a.id, attribution.attributed_event_id ORDER BY a._daton_batch_runtime DESC) = 1)
 where coalesce(Campaign_id,Flow_id) in (select distinct ids from names)
)
)
select * EXCEPT ( send_date1,id,send_date),coalesce(SAFE_CAST(send_date1 AS DATE),send_date) as send_date from 

-- names n 
(select * from matrix where event_date<'2025-01-01') m 
left join 
  -- matrix m 
  
names n 
on n.ids=coalesce(Flow_id,Campaign_id)
-- left join
-- (select distinct Flow_id id3,send_date sndate from matrix) d on n.ids=d.id3
-- where type is null