with date_array as(
SELECT
distinct
date_trunc(date_value,week) AS week_start_date,
dense_rank() over(order by date_trunc(date_value,week)) rank
FROM UNNEST(GENERATE_DATE_ARRAY('2023-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value
),
 
received_email as
(
    select
    date_trunc(date,week) AS week_start_date,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Received_Email
from {{ ref('klaviyo_email_received') }}
where date >= '2023-01-01'
group by 1
),
 
received_sms as
(
    select date_trunc(date,week) AS week_start_date,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Received_SMS,
from {{ ref('klaviyo_sms_received') }}
where date >= '2023-01-01'
group by 1
),

opened_email as
(
    select date_trunc(date,week) AS week_start_date,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Opened_Email,
from {{ ref('klaviyo_emal_opened') }}
where date >= '2023-01-01'
group by 1
),
 
clicked_email as
(
    select
    date_trunc(date,week) AS week_start_date,
COUNT(DISTINCT data_profile_id) Clicked_Email,
from {{ ref('klaviyo_email_clicked') }}
where date >= '2023-01-01'
group by 1
),
 
clicked_sms as
(
    select date_trunc(date,week) AS week_start_date,
COUNT(DISTINCT COALESCE(data_profile_id, data_profile_id2)) Clicked_SMS,
from {{ ref('klaviyo_sms_clicked') }}
where date >= '2023-01-01'
group by 1
),
 
orders as
(
   select * from
    (
        select 
        date_trunc(date,week) AS week_start_date,
        channel,
        sum(orders) as orders,
        sum(Revenue) as Revenue
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
    
    pivot
    (
        sum(orders) orders,sum(revenue) revenue
        for channel in ('Email_campaign','Email_Flow','SMS_Campaign','SMS_Flow')
    )
)
 
,report as( 
select a.*,
b.received_email,
c.received_sms,
d.opened_email,
e.clicked_email,
f.clicked_sms,
g.orders_email_campaign,
g.revenue_Email_campaign,
g.orders_Email_Flow,
g.revenue_Email_Flow,
g.orders_SMS_campaign,
g.revenue_SMS_campaign,
g.orders_SMS_Flow,
g.revenue_SMS_Flow,
g.orders_email_campaign+g.orders_Email_Flow Email_Orders,
g.orders_SMS_campaign+g.orders_SMS_Flow SMS_Orders,
g.revenue_email_campaign+g.revenue_Email_Flow Email_Revenue,
g.revenue_SMS_campaign+g.revenue_SMS_Flow SMS_revenue,
d.opened_email/b.received_email Email_Open_Rate,
e.clicked_email/b.received_email Email_Click_Rate,
(g.orders_email_campaign+g.orders_Email_Flow)/b.received_email Email_CR,
f.clicked_sms/c.received_sms SMS_Click_Rate,
(g.orders_SMS_campaign+g.orders_SMS_Flow)/c.received_sms SMS_CR

from date_array a
left join received_email b
on a.week_start_date = b.week_start_date
left join received_sms c
on a.week_start_date = c.week_start_date
left join opened_email d
on a.week_start_date = d.week_start_date
left join clicked_email e
on a.week_start_date = e.week_start_date
left join clicked_sms f
on a.week_start_date = f.week_start_date
left join orders g
on a.week_start_date = g.week_start_date)

,final_report as(
select a.* ,
b.received_email AS LY_received_email,
b.received_sms AS LY_received_sms,
b.opened_email AS LY_opened_email,
b.clicked_email AS LY_clicked_email,
b.clicked_sms AS LY_clicked_sms,
b.orders_email_campaign AS LY_orders_email_campaign,
b.revenue_Email_campaign AS LY_revenue_Email_campaign,
b.orders_Email_Flow AS LY_orders_Email_Flow,
b.revenue_Email_Flow AS LY_revenue_Email_Flow,
b.orders_SMS_campaign AS LY_orders_SMS_campaign,
b.revenue_SMS_campaign AS LY_revenue_SMS_campaign,
b.orders_SMS_Flow AS LY_orders_SMS_Flow,
b.revenue_SMS_Flow AS LY_revenue_SMS_Flow,
b.Email_orders as LY_Email_orders,
b.SMS_orders LY_SMS_orders,
b.Email_Revenue LY_Email_Revenue,
b.SMS_Revenue LY_SMS_Revenue,
b.Email_Open_Rate LY_Email_Open_Rate,
b.Email_click_rate LY_Email_click_rate,
b.Email_CR LY_Email_CR,
b.SMS_click_rate LY_SMS_click_rate,
b.SMS_CR LY_SMS_CR
from report a
left join report b
on a.rank - 52 = b.rank)

select
*,
(received_email - IFNULL(LY_received_email, 0)) / NULLIF(LY_received_email, 0) AS Vs_LY_Received_Email,
(received_sms - IFNULL(LY_received_sms, 0)) / NULLIF(LY_received_sms, 0) AS Vs_LY_Received_SMS,
(opened_email - IFNULL(LY_opened_email, 0)) / NULLIF(LY_opened_email, 0) AS Vs_LY_Opened_Email,
(clicked_email - IFNULL(LY_clicked_email, 0)) / NULLIF(LY_clicked_email, 0) AS Vs_LY_Clicked_Email,
(clicked_SMS - IFNULL(LY_clicked_SMS, 0)) / NULLIF(LY_clicked_SMS, 0) AS Vs_LY_Clicked_SMS,
(orders_email_campaign - IFNULL(LY_orders_email_campaign, 0)) / NULLIF(LY_orders_email_campaign, 0) AS Vs_LY_Orders_Email_Campaign,
(revenue_email_campaign - IFNULL(LY_revenue_email_campaign, 0)) / NULLIF(LY_revenue_email_campaign, 0) AS Vs_LY_Revenue_Email_Campaign,
(Orders_email_flow - IFNULL(LY_orders_Email_Flow, 0)) / NULLIF(LY_orders_Email_Flow, 0) AS Vs_LY_Orders_Email_Flow,
(revenue_email_flow - IFNULL(LY_revenue_Email_Flow, 0)) / NULLIF(LY_revenue_Email_Flow, 0) AS Vs_LY_Revenue_Email_Flow,
(orders_sms_campaign - IFNULL(LY_orders_SMS_campaign, 0)) / NULLIF(LY_orders_SMS_campaign, 0) AS Vs_LY_Orders_SMS_Campaign,
(revenue_sms_campaign - IFNULL(LY_revenue_SMS_campaign, 0)) / NULLIF(LY_revenue_SMS_campaign, 0) AS Vs_LY_Revenue_SMS_Campaign,
(Orders_sms_flow - IFNULL(LY_orders_SMS_Flow, 0)) / NULLIF(LY_orders_SMS_Flow, 0) AS Vs_LY_Orders_SMS_Flow,
(revenue_sms_flow - IFNULL(LY_revenue_SMS_Flow, 0)) / NULLIF(LY_revenue_SMS_Flow, 0) AS Vs_LY_Revenue_SMS_Flow,
(Email_orders - IFNULL(LY_Email_orders, 0)) / NULLIF(LY_Email_orders, 0) AS Vs_LY_Email_Orders,
(SMS_orders - IFNULL(LY_SMS_orders, 0)) / NULLIF(LY_SMS_orders, 0) AS Vs_LY_SMS_Orders,
(Email_revenue - IFNULL(LY_Email_revenue, 0)) / NULLIF(LY_Email_revenue, 0) AS Vs_LY_Email_Revenue,
(Sms_revenue - IFNULL(LY_Sms_revenue, 0)) / NULLIF(LY_Sms_revenue, 0) AS Vs_LY_SMS_Revenue,
(Email_Open_rate - IFNULL(LY_Email_Open_rate, 0)) / NULLIF(LY_Email_Open_rate, 0) AS Vs_LY_Email_Open_Rate,
(Email_click_rate - IFNULL(LY_Email_click_rate, 0)) / NULLIF(LY_Email_click_rate, 0) AS Vs_LY_Email_Click_Rate,
(Email_CR - IFNULL(LY_Email_CR, 0)) / NULLIF(LY_Email_CR, 0) AS Vs_LY_Email_CR,
(SMS_click_rate - IFNULL(LY_SMS_click_rate, 0)) / NULLIF(LY_SMS_click_rate, 0) AS Vs_LY_SMS_Click_Rate,
(SMS_CR - IFNULL(LY_SMS_CR, 0)) / NULLIF(LY_SMS_CR, 0) AS Vs_LY_SMS_CR
from final_report
where week_start_date < date_trunc(current_date(),week)
 
 
 