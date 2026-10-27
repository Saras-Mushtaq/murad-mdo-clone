select
date Event_Date,
event_properties_message ID,
event_properties_flow flow_ID,
event_properties_Campaign_Name campaign_name,
'Email' as Channel,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Opened_Email,
COUNT(COALESCE(data_profile_id, data_profile_id2)) Total_Opened_Email
from {{ ref('klaviyo_emal_opened') }}
group by 1,2,3,4
