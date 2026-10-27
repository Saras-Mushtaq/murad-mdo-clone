select
date Event_Date,
event_properties_message ID,
event_properties_flow flow_ID,
event_properties_Campaign_Name campaign_name,
'Email' as Channel,
COUNT(DISTINCT data_profile_id) Clicked_Email,
COUNT(data_profile_id) Total_Clicked_Email
from {{ ref('klaviyo_email_clicked') }}
group by 1,2,3,4,5
