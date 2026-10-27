WITH flow_data AS (
    SELECT * FROM {{ ref('klaviyo_flow') }}
),
email_received AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(Total_Received_Email), 0) AS Received
    FROM {{ ref('klaviyo_received_email') }}
    GROUP BY flow_ID, Event_Date, Channel
),
email_clicked AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(Total_Clicked_Email), 0) AS Clicked
    FROM {{ ref('klaviyo_clicked_email') }}
    GROUP BY flow_ID, Event_Date, Channel
),
email_opened AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(Total_Opened_Email), 0) AS Opened
    FROM {{ ref('klaviyo_opened_email') }}
    GROUP BY flow_ID, Event_Date, Channel
),
email_orders AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(orders), 0) AS Orders,
        COALESCE(SUM(Revenue), 0) AS Revenue
    FROM {{ ref('klaviyo_orders_email_flow') }}
    GROUP BY flow_ID, Event_Date, Channel
),
sms_received AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(Total_Received_SMS), 0) AS Received
    FROM {{ ref('klaviyo_received_sms') }}
    GROUP BY flow_ID, Event_Date, Channel
),
sms_clicked AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(Total_Clicked_SMS), 0) AS Clicked
    FROM {{ ref('klaviyo_clicked_sms') }}
    GROUP BY flow_ID, Event_Date, Channel
),
sms_orders AS (
    SELECT
        flow_ID,
        Event_Date,
        Channel,
        COALESCE(SUM(orders), 0) AS Orders,
        COALESCE(SUM(Revenue), 0) AS Revenue
    FROM {{ ref('klaviyo_orders_sms_flow') }}
    GROUP BY flow_ID, Event_Date, Channel
),
Email_data as(
SELECT
    case when flow_data.Name='Session Abandonment' then '*** Session Abandonment' else
    flow_data.Name end as name,
    flow_data.date date,
    COALESCE(email_received.Channel, email_clicked.Channel, email_opened.Channel, email_orders.Channel) AS Channel,
    COALESCE(email_received.Received, 0) AS Received,
    COALESCE(email_clicked.Clicked, 0) AS Clicked,
    COALESCE(email_opened.Opened, 0) AS Opened,
    COALESCE(email_orders.Orders, 0) AS Orders,
    COALESCE(email_orders.Revenue, 0) AS Revenue
FROM flow_data
LEFT JOIN email_received ON flow_data.id = email_received.flow_ID AND flow_data.date = email_received.Event_Date
LEFT JOIN email_clicked ON flow_data.id = email_clicked.flow_ID AND flow_data.date = email_clicked.Event_Date
LEFT JOIN email_opened ON flow_data.id = email_opened.flow_ID AND flow_data.date = email_opened.Event_Date
LEFT JOIN email_orders ON flow_data.id = email_orders.flow_ID AND flow_data.date = email_orders.Event_Date
WHERE COALESCE(email_received.Received, 0) 
    + COALESCE(email_clicked.Clicked, 0) 
    + COALESCE(email_opened.Opened, 0) 
    + COALESCE(email_orders.Orders, 0) 
    + COALESCE(email_orders.Revenue, 0) != 0 
),
SMS_Data as(
SELECT
    flow_data.Name name,
    flow_data.date date,
    COALESCE(sms_received.Channel, sms_clicked.Channel, sms_orders.Channel) AS Channel,
    COALESCE(sms_received.Received, 0) AS Received,
    COALESCE(sms_clicked.Clicked, 0) AS Clicked,
    0 as Opened,
    COALESCE(sms_orders.Orders, 0) AS Orders,
    COALESCE(sms_orders.Revenue, 0) AS Revenue
FROM flow_data
LEFT JOIN sms_received ON flow_data.id = sms_received.flow_ID AND flow_data.date = sms_received.Event_Date
LEFT JOIN sms_clicked ON flow_data.id = sms_clicked.flow_ID AND flow_data.date = sms_clicked.Event_Date
LEFT JOIN sms_orders ON flow_data.id = sms_orders.flow_ID AND flow_data.date = sms_orders.Event_Date
WHERE COALESCE(sms_received.Received, 0)
    + COALESCE(sms_clicked.Clicked, 0)
    + COALESCE(sms_orders.Orders, 0)
    + COALESCE(sms_orders.Revenue, 0) != 0
)
select * from(
select * from Email_data
union all
select * from SMS_Data
)