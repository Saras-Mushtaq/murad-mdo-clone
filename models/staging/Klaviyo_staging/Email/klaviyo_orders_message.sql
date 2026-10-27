 select 
 date Event_Date, 
attribution_message ID,
attribution_flow flow_ID,
'SMS' as Channel,
 count(distinct order_id) Orders, 
 sum(coalesce(event_properties_value,0)) Revenue
 from 
{{ ref('Klaviyo_orders') }}
 where attributed_channel='$sms_channel' and attribution_flow is not null and attribution_message is not null
 group by 1,2,3,4
 order by 1  
