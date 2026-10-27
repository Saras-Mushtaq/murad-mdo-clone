WITH received AS (
    SELECT 
        id,
        campaign_name,
        Event_Date,
        channel,
        COALESCE(SUM(Received_Email), 0) AS Received,
        COALESCE(SUM(Received_Email), 0) AS total_Received
    FROM {{ ref('klaviyo_received_email') }}
    GROUP BY 1,2,3,4
),

Total_received AS (
    SELECT 
        id,
        Case when (id='01JTPH9SG03MP6G4THHQKP4ZK0' or id='01JSCXHB7R0PX0K7JS2BPTJ6WX') then 349239 else
        COALESCE(SUM(Total_Received_Email), 0) end AS total_Received
    FROM {{ ref('klaviyo_received_email') }}
    GROUP BY id
),
Total_received_sms AS (
    SELECT 
        id,
        REGEXP_REPLACE(Campaign_Name, r' - (Emoji|No Emoji)$', '') AS Campaign_Name,
        COALESCE(SUM(Total_Received_SMS), 0) AS total_Received
    FROM {{ ref('klaviyo_received_sms') }}
    GROUP BY 1,2
),
emailcamp as(
    select distinct id, Campaign_Name from  {{ ref('klaviyo_received_email') }} where flow_ID is null

), 
email_camp as(
    select distinct id,campaign_name as name, date from
    emailcamp 
    cross join 
    (SELECT 
    date_value AS date
    FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates
),
clicked AS (
    SELECT 
        id,
        campaign_name,
        Event_Date,
        channel,
        COALESCE(SUM(Clicked_Email), 0) AS Clicked,
        COALESCE(SUM(total_Clicked_Email), 0) AS Total_Clicked
    FROM {{ ref('klaviyo_clicked_email') }}
    GROUP BY 1,2,3,4
),

opened AS (
    SELECT 
        id,
        Event_Date,
        channel,
        campaign_name,
        COALESCE(SUM(Opened_Email), 0) AS Opened,
        COALESCE(SUM(total_Opened_Email), 0) AS Total_Opened
    FROM {{ ref('klaviyo_opened_email') }}
    GROUP BY 1,2,3,4
),

orders as(
    SELECT 
        id,
        Event_Date,
        channel,
        cast(sum(case when Event_Date < '2024-02-27' then orders/2 else orders end) as numeric) orders,
        cast(sum(case when Event_Date < '2024-02-27' then Revenue/2 else Revenue end) as numeric) Revenue
    from (
        SELECT 
        id,
        Event_Date,
        channel,
        COALESCE(SUM(orders), 0) AS Orders,
        COALESCE(SUM(Revenue), 0) AS Revenue
    FROM {{ ref('klaviyo_orders_email_campaign') }}
    GROUP BY id, Event_Date,channel
    )
    GROUP BY id, Event_Date,channel
),received_sms AS (
    SELECT 
        id,
        REGEXP_REPLACE(Campaign_Name, r' - (Emoji|No Emoji)$', '') AS Campaign_Name,
        Event_Date,
        channel,
        COALESCE(SUM(Received_SMS), 0) AS Received,
        COALESCE(SUM(Total_Received_SMS), 0) AS total_Received
    FROM {{ ref('klaviyo_received_sms') }}
    GROUP BY id,Campaign_Name, Event_Date,channel    
),
smscamp as(
    select distinct id,REGEXP_REPLACE(Campaign_Name, r' - (Emoji|No Emoji)$', '') AS Campaign_Name from {{ ref('klaviyo_received_sms') }} where flow_ID is null
), 
sms_camp as(
    select distinct id,campaign_name as name, date from
    smscamp 
    cross join 
    (SELECT 
    date_value AS date
    FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates
),
clicked_sms AS (
    SELECT 
        id,
        REGEXP_REPLACE(Campaign_Name, r' - (Emoji|No Emoji)$', '') AS Campaign_Name,
        Event_Date,
        channel,
        COALESCE(SUM(Clicked_SMS), 0) AS Clicked,
        COALESCE(SUM(total_Clicked_SMS), 0) AS Total_Clicked
    FROM {{ ref('klaviyo_clicked_sms') }}
    GROUP BY 1,2,3,4
),
orders_sms AS (
    SELECT 
       id,
        Campaign_Name ,
       Event_Date,
       cast(sum(case when Event_Date < '2024-02-25' then orders/2 else orders end) as numeric) orders,
        cast(sum(case when Event_Date < '2024-02-25' then Revenue/2 else Revenue end) as numeric) Revenue
        from(
            select
            a.id as id,
        REGEXP_REPLACE(b.Name, r' - (Emoji|No Emoji)$', '') AS Campaign_Name ,
        a.Event_Date as Event_Date,
        COALESCE(SUM(orders), 0) AS Orders,
        COALESCE(SUM(Revenue), 0) AS Revenue
    FROM {{ ref('klaviyo_orders_sms_campaign') }} a left join sms_camp b on a.id=b.id and a.event_date=b.date
    GROUP BY 1,2,3
        )
    GROUP BY 1,2,3
),
email_data as(
SELECT 
    campaign.Name,
    campaign.date,
    -- IFNULL(
    case when campaign.Name='04144_Multi Vitamin Clear Coat SPF MVCC Back in Stock' then '2024-04-14' 
    when campaign.Name='06044_Free Trio with $85 #2 Reminder' then '2024-06-04'
    when campaign.Name='08105_Retinal Night Cream #4 All about NAD' then '2025-08-10'
    when campaign.Name='10085_Loyalty Members 1000 points Retinol Youth Renewal Serum' then '2025-10-08'
    when campaign.Name='10075_Loyalty Members 1000 points Retinol Youth Renewal Serum' then '2025-10-07'
      when campaign.Name='1106224_Invisiblur SubscriptionAHA/BHA Exfoliating Cleanser' then '2024-06-11' 
     else
    SAFE.PARSE_DATE('%Y-%m-%d', 
      CONCAT('20', SUBSTRING(SPLIT(campaign.Name, '_')[OFFSET(0)], 5, 2), '-', 
             SUBSTRING(SPLIT(campaign.Name, '_')[OFFSET(0)], 1, 2), '-', 
             SUBSTRING(SPLIT(campaign.Name, '_')[OFFSET(0)], 3, 2)))
            --  , campaign.send_date) 
            end AS send_date,
    COALESCE(Total_received.total_Received,0) Total_sent,
    'Email' AS channel,
    COALESCE(received.Received, 0) AS Received,
    COALESCE(received.total_Received, 0) AS total_Received,
    COALESCE(clicked.Clicked, 0) AS Clicked,
    COALESCE(clicked.Total_Clicked, 0) AS Total_Clicked,
    COALESCE(opened.Opened, 0) AS Opened,
    COALESCE(opened.Total_Opened, 0) AS Total_Opened,
    COALESCE(orders.Orders, 0) AS Orders,
    COALESCE(orders.Revenue, 0) AS Revenue
FROM email_camp campaign
LEFT JOIN Total_received ON campaign.id = Total_received.id 
LEFT JOIN received ON campaign.id = received.id AND campaign.date = received.Event_Date
LEFT JOIN clicked ON campaign.id = clicked.id AND campaign.date = clicked.Event_Date
LEFT JOIN opened ON campaign.id = opened.id AND campaign.date = opened.Event_Date
LEFT JOIN orders ON campaign.id = orders.id AND campaign.date = orders.Event_Date
where COALESCE(received.Received, 0)+COALESCE(clicked.Clicked, 0)+COALESCE(opened.Opened, 0)+COALESCE(orders.Orders, 0)+COALESCE(orders.Revenue, 0) != 0
),


sms_data as(
SELECT 
    campaign.Name,
    campaign.date,
        -- IFNULL(

case when campaign.Name='052223_Memorial Day: 25% Off $100 VIP SMS' then '2024-05-22' 
    else 
    SAFE.PARSE_DATE('%Y-%m-%d', 
      CONCAT('20', SUBSTRING(SPLIT(campaign.Name, '_')[OFFSET(0)], 5, 2), '-', 
             SUBSTRING(SPLIT(campaign.Name, '_')[OFFSET(0)], 1, 2), '-', 
             SUBSTRING(SPLIT(campaign.Name, '_')[OFFSET(0)], 3, 2))) end AS send_date, 
    -- campaign.send_date) AS send_date,   
    COALESCE(Total_received_sms.total_Received,0) Total_sent, 
  'SMS' AS channel,
    COALESCE(received_sms.Received, 0) AS Received,
    COALESCE(received_sms.total_Received, 0) AS total_Received,
    COALESCE(clicked_sms.Clicked, 0) AS Clicked,
    COALESCE(clicked_sms.Total_Clicked, 0) AS Total_Clicked,
    0 as Opened,
    0 as Total_opened,
    COALESCE(orders_sms.Orders, 0) AS Orders,
    COALESCE(orders_sms.Revenue, 0) AS Revenue
FROM sms_camp campaign
LEFT JOIN Total_received_sms ON LOWER(campaign.name) = LOWER(Total_received_sms.Campaign_Name )
LEFT JOIN received_sms ON LOWER(campaign.name) = LOWER(received_sms.Campaign_Name) AND campaign.date = received_sms.Event_Date
LEFT JOIN clicked_sms ON LOWER(campaign.Name) = LOWER(clicked_sms.Campaign_Name) AND campaign.date = clicked_sms.Event_Date
LEFT JOIN orders_sms ON LOWER(campaign.Name) = LOWER(orders_sms.Campaign_Name) AND campaign.date = orders_sms.Event_Date
where COALESCE(clicked_sms.Clicked, 0)+COALESCE(orders_sms.Orders, 0)+COALESCE(orders_sms.Revenue, 0)!=0
)
select * from(
select * from Email_data
union all
select * from sms_data 
) 

