WITH base AS (

SELECT
  event_properties.email_address,
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS STRING) AS events,
  DATE(DATETIME(datetime, "America/Los_Angeles")) AS event_date,
  'Sub' Event

FROM murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_subscribed_to_email_marketing a

LEFT JOIN UNNEST(attributes) attributes
LEFT JOIN UNNEST(attributes.event_properties) event_properties
LEFT JOIN UNNEST(links) links
LEFT JOIN UNNEST(relationships) relationships
LEFT JOIN UNNEST(relationships.profile) profile
LEFT JOIN UNNEST(profile.data) data

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY id
    ORDER BY _daton_batch_runtime DESC
) = 1

)
(
SELECT
    *,
    
    CASE
        WHEN ROW_NUMBER() OVER (
            PARTITION BY LOWER(TRIM(email_address))
            ORDER BY event_date
        ) = 1
        THEN 1
        ELSE 0
    END AS is_new_subscriber

FROM base)
union all
(
    
SELECT
  event_properties.email_address,
  COALESCE(a.id, 'N/A') AS id,
  CAST(data.id AS STRING) AS events,
  DATE(DATETIME(datetime, "America/Los_Angeles")) AS event_date,
  'UnSub' Event,
  0 

FROM murad-data-warehouse.BigQuery.Murad_US_Klaviyo_V3_unsubscribed_from_email_marketing a

LEFT JOIN UNNEST(attributes) attributes
LEFT JOIN UNNEST(attributes.event_properties) event_properties
LEFT JOIN UNNEST(links) links
LEFT JOIN UNNEST(relationships) relationships
LEFT JOIN UNNEST(relationships.profile) profile
LEFT JOIN UNNEST(profile.data) data

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY id
    ORDER BY _daton_batch_runtime DESC
) = 1
)