select
date Event_Date,
event_properties_Campaign_Name as Campaign_Name,
event_properties_message ID,
event_properties_flow flow_ID,
'Email' as Channel,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Received_Email,
-- Case when event_properties_Campaign_Name='042925_25% Off $100 LAST CHANCE' then 635694/2 else
COUNT(COALESCE(data_profile_id, data_profile_id2)) as Total_Received_Email
from(SELECT
  'Murad' AS brand,
  'US' AS store,
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS string) AS data_profile_id,
  CAST(data2.id AS string) AS data_profile_id2,
  CAST(event_properties.flow AS string) AS event_properties_flow,
  CAST(event_properties.message AS string) AS event_properties_message,
  CAST(event_properties.Campaign_Name AS string) AS event_properties_Campaign_Name,
  CAST(event_properties.cohort_message_send_cohort AS string) AS event_properties_cohort_message_send_cohort,
  date(TIMESTAMP_SUB(CAST(CASE
        WHEN LENGTH(datetime) = 17 THEN REPLACE(datetime,"Z",":00+00:00")
        WHEN LENGTH(datetime) = 20 THEN REPLACE(datetime,"Z","+00:00")
        ELSE datetime
    END
      AS timestamp), INTERVAL 8 hour)) date,
  a. _daton_user_id AS _daton_user_id,
  a. _daton_batch_runtime AS _daton_batch_runtime,
  a. _daton_batch_id AS _daton_batch_id,
  CURRENT_TIMESTAMP() AS _last_updated,
  'manual' AS _run_id
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
  ROW_NUMBER() OVER (PARTITION BY id ORDER BY _daton_batch_runtime DESC) = 1
)
group by 1,2,3,4,5
