SELECT
    id ID,
    name Name,
    date(TIMESTAMP_SUB(CAST (updated as timestamp), INTERVAL 8 hour)) Send_Date,
    date
FROM {{ ref('klaviyo_all_campaigns') }}
CROSS JOIN
(SELECT 
date_value AS date
FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates 