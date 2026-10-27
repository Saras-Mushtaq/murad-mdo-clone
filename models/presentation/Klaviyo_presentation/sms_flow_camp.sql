SELECT 
 distinct 
 COALESCE(a.id, 'N/A') AS id, 
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
 where  date(TIMESTAMP_SUB(CAST(CASE
        WHEN LENGTH(datetime) = 17 THEN REPLACE(datetime,"Z",":00+00:00")
        WHEN LENGTH(datetime) = 20 THEN REPLACE(datetime,"Z","+00:00")
        ELSE datetime
    END
      AS timestamp), INTERVAL 8 hour)) between '2025-01-01' and '2025-02-28' and cast(attribution.attributed_channel as string)='$sms_channel'
 QUALIFY DENSE_RANK() OVER(PARTITION BY a.id, attribution.attributed_event_id ORDER BY a._daton_batch_runtime DESC) = 1 