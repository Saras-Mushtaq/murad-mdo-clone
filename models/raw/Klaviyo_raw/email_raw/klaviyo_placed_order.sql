-- used in single matric report
SELECT
'Murad' AS brand,
'US' AS store,
a.type,
case 
when lower(cast(attribution.attributed_channel as string)) like '%sms%' 
and CAST(attribution.flow AS string) is null then 'SMS_Campaign'
when lower(cast(attribution.attributed_channel as string)) like '%sms%' 
and CAST(attribution.flow AS string) is not null then 'SMS_Flow'
when (lower(cast(attribution.attributed_channel as string)) is null or lower(cast(attribution.attributed_channel as string)) like '%email%')  and
CAST(attribution.message AS string) in (select distinct event_properties_message from {{ ref('klaviyo_email_received') }} where event_properties_flow is null)
and CAST(attribution.flow AS string) is null then 'Email_campaign'
when (lower(cast(attribution.attributed_channel as string)) is null or lower(cast(attribution.attributed_channel as string)) like '%email%')
and CAST(attribution.flow AS string) is not null then 'Email_Flow'
else 'Other'
end channel,
case when CAST(attribution.flow AS string) is null then 'Campaign' else 'Flow' end channel_type,
COALESCE(a.id, 'N/A') AS id,
CAST(data.id AS string) AS data_profile_id,
CAST(extra.id AS NUMERIC) AS order_id,
CAST(event_properties.item_count AS numeric) AS event_properties_item_count,
CAST(event_properties.currency_code AS string) AS event_properties_currency_code,
CAST(event_properties.value AS numeric) AS event_properties_value,
CAST(attribution.message AS string) AS attribution_message,
CAST(attribution.flow AS string) AS attribution_flow,
CAST(attribution.send_ts AS string) AS send_ts,
CAST(extra.cancelled_at AS string) AS is_cancelled,
COALESCE( CAST(attribution.attributed_event_id AS string), 'N/A') AS attribution_attributed_event_id,
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

-- where _daton_batch_runtime  >= (select coalesce(max(_daton_batch_runtime) - 2592000000,0) from murad-data-warehouse.dev_raw.klaviyo_placed_order)
QUALIFY DENSE_RANK() OVER(PARTITION BY a.id, attribution.attributed_event_id ORDER BY a._daton_batch_runtime DESC) = 1