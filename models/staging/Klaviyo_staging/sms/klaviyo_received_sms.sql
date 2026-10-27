
select
date Event_Date,
event_properties_message id,
event_properties_Campaign_Name Campaign_Name,
event_properties_flow flow_ID,
'SMS' as Channel,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Received_SMS,
COUNT(COALESCE(data_profile_id, data_profile_id2)) Total_Received_SMS
from {{ ref('klaviyo_sms_received') }}
group by 1,2,3,4
