{{ config(enabled = False) }}

-- with base as(
--    Select case when Murad_Marketing_Channel is null then 'Unassigned' else Murad_Marketing_Channel end as Murad_Marketing_Channel ,date from {{ ref('GA4_Sessions') }}
--    union all
--    select case when Murad_Marketing_Channel is null then 'Unassigned' else Murad_Marketing_Channel end as Murad_Marketing_Channel,date from {{ ref('GA4_Transaction') }}
-- )
(select `Session Murad Marketing Channels` as Marketing_channel,PARSE_DATE('%Y%m%d', date) as Date,CAST(Sessions AS INT64) AS Sessions,CAST(Transactions AS INT64) AS Transactions,CAST(`Net revenue` AS FLOAT64) AS Net_Revenue
 from murad-data-warehouse.BigQuery.GA4_Historical_Data_Jan24ToOct24)

union all
-- (
--     Select base.Murad_Marketing_Channel,base.date,Sessions,Transactions,Net_revenue 
--     from
--     ((select distinct Murad_Marketing_Channel,date from base ) base left join
--     (
--         select case when Murad_Marketing_Channel is null then 'Unassigned' else Murad_Marketing_Channel end as Murad_Marketing_Channel,date,count(*) as Sessions from {{ ref('GA4_Sessions') }} group by 1,2
--     ) session on base.Murad_Marketing_Channel=session.Murad_Marketing_Channel and base.date=session.date
--     left join
--     (
--         select case when Murad_Marketing_Channel is null then 'Unassigned' else Murad_Marketing_Channel end as Murad_Marketing_Channel,date,count(distinct Transaction_id) as Transactions,sum(Total_revenue)-sum(Tax)-sum(Shipping_cost) as Net_revenue from {{ ref('GA4_Transaction') }} group by 1,2
--     ) transaction
--     on base.Murad_Marketing_Channel=transaction.Murad_Marketing_Channel and base.date=transaction.date)

-- ) 

(
    Select session.Murad_Marketing_Channel,session.date,Sessions,Transactions,Net_revenue 
        from
         (
        select Murad_Marketing_Channel,date,count(*) as Sessions from {{ ref('GA4_Sessions') }} group by 1,2
    ) session
    left join
    (
        select Murad_Marketing_Channel,date,count(distinct Transaction_id) as Transactions,sum(Total_revenue)-sum(Tax)-sum(Shipping_cost) as Net_revenue from {{ ref('GA4_Transaction') }} group by 1,2
          ) transaction
    on session.Murad_Marketing_Channel=transaction.Murad_Marketing_Channel and session.date=transaction.date
    
)