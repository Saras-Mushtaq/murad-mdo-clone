{{ config(enabled = False) }}

{{
    config(materilized='incremental',incremental_strategy = 'merge')
}}

SELECT
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
LEFT JOIN UNNEST(a.attributes) AS attributes
LEFT JOIN UNNEST(attributes.event_properties) AS event_properties
LEFT JOIN UNNEST(a.links) AS links
LEFT JOIN UNNEST(a.relationships) AS relationships
LEFT JOIN UNNEST(relationships.profile) AS profile
LEFT JOIN UNNEST(relationships.profiles) AS profiles
LEFT JOIN UNNEST(profile.data) AS data
LEFT JOIN UNNEST(profiles.data) AS data2


WHERE TRUE  
{% if is_incremental() %}
  AND a._daton_batch_runtime >= (
    SELECT COALESCE(MAX(_daton_batch_runtime), 0) - {{ var('klaviyo_campaigns_lookback', 0) }}
    FROM {{ this }}
  )
{% endif %}

QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _daton_batch_runtime DESC) = 1
