With Final as
(
  SELECT Send_date as `Date` ,*, 'Send' AS date_type FROM `prod_presentation.Attentive_Combined`
  UNION ALL
  SELECT event_date as `Date`,*, 'Event' AS date_type FROM `prod_presentation.Sms`
--   UNION ALL
--   SELECT event_date as `Date`,*, 'event_date' AS date_type FROM {{ref("Sms")}}
)
select * from Final 