with date_array as(
SELECT
distinct
date_trunc(date_value,week) AS week_start_date,
dense_rank() over(order by date_trunc(date_value,week)) rank
FROM UNNEST(GENERATE_DATE_ARRAY('2023-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value
),

CTE_received_email as
(select
date_trunc(date,week) AS week_start_date,
'Unique Recipient' as metric,
'email' as channel,
cast(COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) as numeric) Received_Email
from {{ ref('klaviyo_email_received') }}
where date >= '2023-01-01'
group by 1,2,3
),

CTE_total_received_email as
(select
date_trunc(date,week) AS week_start_date,
'Total Recipient' as metric,
'email' as channel,
cast(COUNT(COALESCE(data_profile_id, data_profile_id2)) as numeric) Received_Email
from {{ ref('klaviyo_email_received') }}
where date >= '2023-01-01'
group by 1,2,3
),
 
CTE_received_sms as
(
select date_trunc(date,week) AS week_start_date,
'Unique Recipient' as metric,
'sms' as channel,
cast(COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) as numeric) Received_SMS
from {{ ref('klaviyo_sms_received') }}
where date >= '2023-01-01'
group by 1,2,3
),

CTE_total_received_sms as
(
select date_trunc(date,week) AS week_start_date,
'Total Recipient' as metric,
'sms' as channel,
cast(COUNT(COALESCE(data_profile_id, data_profile_id2)) as numeric) Received_SMS
from {{ ref('klaviyo_sms_received') }}
where date >= '2023-01-01'
group by 1,2,3
),

CTE_opened_email as
(
    select date_trunc(date,week) AS week_start_date,
    'Opened' as metric,
    'email' as channel,
cast(COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) as numeric) Opened_Email
from {{ ref('klaviyo_emal_opened') }}
where date >= '2023-01-01'
group by 1,2,3
),
 
CTE_clicked_email as
(
    select
    date_trunc(date,week) AS week_start_date,
    'Unique Clicks' as metric,
    'email' as channel,
COUNT(DISTINCT data_profile_id) Clicked_Email
from {{ ref('klaviyo_email_clicked') }}
where date >= '2023-01-01'
group by 1,2,3
),

CTE_total_clicked_email as
(
    select
    date_trunc(date,week) AS week_start_date,
    'Total Clicks' as metric,
    'email' as channel,
cast(COUNT(data_profile_id) as numeric) Clicked_Email
from {{ ref('klaviyo_email_clicked') }}
where date >= '2023-01-01'
group by 1,2,3
),
 
CTE_clicked_sms as
(
    select date_trunc(date,week) AS week_start_date,
    'Unique Clicks' as metric,
    'sms' as channel,
cast(COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) as numeric) Clicked_SMS
from {{ ref('klaviyo_sms_clicked') }}
where date >= '2023-01-01'
group by 1,2,3
),

CTE_total_clicked_sms as
(
    select date_trunc(date,week) AS week_start_date,
    'Total Clicks' as metric,
    'sms' as channel,
cast(COUNT(COALESCE(data_profile_id, data_profile_id2)) as numeric) Clicked_SMS
from {{ ref('klaviyo_sms_clicked') }}
where date >= '2023-01-01'
group by 1,2,3
),
 
CTE_order_table as
(
        select 
        date_trunc(date,week) AS week_start_date,
        case when lower(channel) like '%email%' then 'email' 
        when lower(channel) like '%sms%' then 'sms'
        else 'other'
        end as channel,
        sum(orders) as orders,
        round(sum(Revenue),0) as Revenue,
        -- cast(sum(case when week_start_date < '2024-02-29' then orders/2 else orders end) as numeric) orders,
        -- cast(sum(case when week_start_date < '2024-02-29' then Revenue/2 else Revenue end) as numeric) Revenue
        from
        (select
        -- date_trunc(date,week) AS week_start_date,
        date,
        channel,
        CASE 
            WHEN date < '2024-02-27' AND channel IN ('Email_Flow', 'Email_campaign', 'SMS_Flow') THEN count(order_id) / 2
            WHEN date < '2024-02-25' AND channel IN ('SMS_Campaign') THEN count(order_id) / 2
            ELSE count(order_id) 
        END AS orders,

        CASE 
            WHEN date < '2024-02-27' AND channel IN ('Email_Flow', 'Email_campaign', 'SMS_Flow') THEN sum(coalesce(event_properties_value,0)) / 2
            WHEN date < '2024-02-25' AND channel IN ('SMS_Campaign') THEN sum(coalesce(event_properties_value,0)) / 2
        ELSE sum(coalesce(event_properties_value,0)) 
        END AS Revenue
        -- count(order_id) orders,
        -- sum(coalesce(event_properties_value,0)) Revenue
        from {{ ref('klaviyo_placed_order') }}
        where date >= '2023-01-01'
        group by 1,2)
        group by 1,2
),

CTE_orders_bifurcated as
(
    select * from
    (
        select 
        date_trunc(date,week) AS week_start_date,
        channel,
        sum(orders) as orders,
        round(sum(Revenue),0) as Revenue
        from
        (select
        date,
        channel,
        CASE 
            WHEN date < '2024-02-27' AND channel IN ('Email_Flow', 'Email_campaign', 'SMS_Flow') THEN count(order_id) / 2
            WHEN date < '2024-02-25' AND channel IN ('SMS_Campaign') THEN count(order_id) / 2
            ELSE count(order_id) 
        END AS orders,

        CASE 
            WHEN date < '2024-02-27' AND channel IN ('Email_Flow', 'Email_campaign', 'SMS_Flow') THEN sum(coalesce(event_properties_value,0)) / 2
            WHEN date < '2024-02-25' AND channel IN ('SMS_Campaign') THEN sum(coalesce(event_properties_value,0)) / 2
        ELSE sum(coalesce(event_properties_value,0)) 
        END AS Revenue
        from {{ ref('klaviyo_placed_order') }}
        where date >= '2023-01-01'
        group by 1,2)
        group by 1,2
    )
    -- pivot
    -- (
    --     sum(orders) orders,sum(revenue) revenue
    --     for channel in ('Email_campaign','Email_Flow','SMS_Campaign','SMS_Flow')
    -- )
)
 




,combined_data AS ( 
    SELECT week_start_date, metric, channel, received_email as metric_value FROM CTE_received_email
    UNION ALL
    SELECT week_start_date, metric, channel, received_email as metric_value FROM CTE_total_received_email
    UNION ALL
    SELECT week_start_date, metric, channel, received_sms as metric_value FROM CTE_received_sms
    UNION ALL
    SELECT week_start_date, metric, channel, received_sms as metric_value FROM CTE_total_received_sms
    UNION ALL
    SELECT week_start_date, metric, channel, opened_email as metric_value FROM CTE_opened_email
    UNION ALL
    SELECT week_start_date, metric, channel, clicked_email as metric_value FROM CTE_clicked_email
    UNION ALL
    SELECT week_start_date, metric, channel, clicked_email as metric_value FROM CTE_total_clicked_email
    UNION ALL
    SELECT week_start_date, metric, channel, clicked_sms as metric_value FROM CTE_clicked_sms
    UNION ALL
    SELECT week_start_date, metric, channel, clicked_sms as metric_value FROM CTE_total_clicked_sms
    UNION ALL
    SELECT week_start_date, 'Total Orders' AS metric, channel, CAST(ROUND(orders,0) AS NUMERIC) AS metric_value
    FROM CTE_order_table WHERE channel != 'other'
    UNION ALL
    SELECT week_start_date, 'Total Revenue' AS metric, channel, CAST(ROUND(revenue,0) AS NUMERIC) AS metric_value
    FROM CTE_order_table WHERE channel != 'other'

    union all
    select a.week_start_date,'Open Rate (%)' as metric,'email' as channel,round((opened_email/received_email)*100,1) as metric_value
    from date_array a
    left join CTE_received_email b
    on a.week_start_date = b.week_start_date
    left join CTE_opened_email c
    on a.week_start_date = c.week_start_date

    union all
    select a.week_start_date,'Click Rate (%)' as metric,'email' as channel,round((clicked_email/received_email)*100,2) as metric_value
    from date_array a
    left join CTE_received_email b
    on a.week_start_date = b.week_start_date
    left join CTE_clicked_email c
    on a.week_start_date = c.week_start_date

    union all
    select a.week_start_date,'Click Rate (%)' as metric,'sms' as channel,round((clicked_sms/received_sms)*100,2) as metric_value
    from date_array a
    left join CTE_received_sms b
    on a.week_start_date = b.week_start_date
    left join CTE_clicked_sms c
    on a.week_start_date = c.week_start_date

    union all
    select a.week_start_date,'Conv Rate (%)' as metric,'email' as channel,round((orders/received_email)*100,2) as metric_value
    from date_array a
    left join CTE_received_email b
    on a.week_start_date = b.week_start_date
    left join (select week_start_date, orders FROM CTE_order_table WHERE channel = 'email') c
    on a.week_start_date = c.week_start_date

    union all
    select a.week_start_date,'Conv Rate (%)' as metric,'sms' as channel,round((orders/received_sms)*100,2) as metric_value
    from date_array a
    left join CTE_received_sms b
    on a.week_start_date = b.week_start_date
    left join (select week_start_date, orders FROM CTE_order_table WHERE channel = 'sms') c
    on a.week_start_date = c.week_start_date

    union all

    select week_start_date,'Campaign Orders' as metric, 'email' as channel,orders as metric_value
from CTE_orders_bifurcated where channel = 'Email_campaign'
union all
select week_start_date,'Campaign Revenue' as metric, 'email' as channel,revenue as metric_value
from CTE_orders_bifurcated where channel = 'Email_campaign'
union all
select week_start_date,'Flow Orders' as metric, 'email' as channel,orders as metric_value
from CTE_orders_bifurcated where channel = 'Email_Flow'
union all
select week_start_date,'Flow Revenue' as metric, 'email' as channel,revenue as metric_value
from CTE_orders_bifurcated where channel = 'Email_Flow'
union all
select week_start_date,'Campaign Orders' as metric, 'sms' as channel,orders as metric_value
from CTE_orders_bifurcated where channel = 'SMS_Campaign'
union all
select week_start_date,'Campaign Revenue' as metric, 'sms' as channel,revenue as metric_value
from CTE_orders_bifurcated where channel = 'SMS_Campaign'
union all
select week_start_date,'Flow Orders' as metric, 'sms' as channel,orders as metric_value
from CTE_orders_bifurcated where channel = 'SMS_Flow'
union all
select week_start_date,'Flow Revenue' as metric, 'sms' as channel,revenue as metric_value
from CTE_orders_bifurcated where channel = 'SMS_Flow'
)



-- select a.* ,
-- b.metric_value LY_metric_value,
-- (a.metric_value - nullif(b.metric_value,0))/nullif(b.metric_value,0) vs_LY
-- from (select *,dense_rank() over(order by week_start_date) rank from report) a
-- left join (select *,dense_rank() over(order by week_start_date) rank from report) b
-- on a.rank - 52 = b.rank
-- and a.channel = b.channel
-- and a.metric = b.metric

,report as(
select * from
(
    select 
    *
    from combined_data
)
pivot
(
    sum(metric_value)
    for channel in ('sms','email')
)
)

-- select * from report

select a.* ,
b.sms LY_sms,
(a.sms - nullif(b.sms,0))/nullif(b.sms,0) vs_LY_sms,
b.email LY_email,
(a.email - nullif(b.email,0))/nullif(b.email,0) vs_LY_email,
CASE 
    WHEN a.metric = 'Total Recipient' THEN 1
    WHEN a.metric = 'Unique Recipient' THEN 2
    WHEN a.metric = 'Opened' THEN 3
    WHEN a.metric = 'Total Clicks' THEN 4
    WHEN a.metric = 'Unique Clicks' THEN 5
    WHEN a.metric = 'Campaign Orders' THEN 6
    WHEN a.metric = 'Flow Orders' THEN 7
    WHEN a.metric = 'Total Orders' THEN 8
    WHEN a.metric = 'Campaign Revenue' THEN 9
    WHEN a.metric = 'Flow Revenue' THEN 10
    WHEN a.metric = 'Total Revenue' THEN 11
    WHEN a.metric = 'Open Rate (%)' THEN 12
    WHEN a.metric = 'Click Rate (%)' THEN 13
    WHEN a.metric = 'Conv Rate (%)' THEN 14
    ELSE NULL
END AS looker_rank

from (select *,dense_rank() over(order by week_start_date) rank from report) a
left join (select *,dense_rank() over(order by week_start_date) rank from report) b
on a.rank - 52 = b.rank
and a.metric = b.metric 
where a.week_start_date < date_trunc(current_date(),week)
