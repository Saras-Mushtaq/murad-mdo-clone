{{ config(
    materialized='table',
    partition_by={
      "field": "order_created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["type", "Platform", "order_id"]
) }}

SELECT 
    type AS Type,
    Platform,b.order_id,b.sku,b.sku_name,discount_code discount_applications_code,Product_Type,
    -- Murad_Marketing_Channel,
    -- Case when Platform='Tiktok' then 'TikTok'
    -- when Platform='Recurring Subscription' then 'Recurring Subscription'
    -- When Murad_Marketing_Channel='Direct' then 'Direct'
    -- When Murad_Marketing_Channel='Affiliates' then 'Affiliate'
    -- When Murad_Marketing_Channel='Organic Search' then 'Organic Search'
    -- When Murad_Marketing_Channel='Paid Social' then 'Meta'
    -- When Murad_Marketing_Channel='Display' then 'TTD'
    -- When Murad_Marketing_Channel='TTD' then 'TTD'
    -- When Murad_Marketing_Channel='SMS' then 'SMS'
    -- When Murad_Marketing_Channel='Email' then 'Email'
    -- When Murad_Marketing_Channel='Paid Search' AND source='google' then 'Google'
    -- When Murad_Marketing_Channel='Paid Search' AND source='bing' then 'Bing'
    -- When Murad_Marketing_Channel='Paid Search' AND source='facebook' then 'Meta'
    -- When Murad_Marketing_Channel='Cross-network' then 'Google'
    -- When Murad_Marketing_Channel='Paid Shopping' AND source='google' then 'Google'
    -- When Murad_Marketing_Channel='Paid Shopping' AND source='bing' then 'Bing'
    -- When Murad_Marketing_Channel='Paid Shopping' AND source='facebook' then 'Meta'
    -- When Murad_Marketing_Channel='Organic Social' then 'Organic Social'
    -- When Murad_Marketing_Channel='Bing' then 'Bing'
    -- When Murad_Marketing_Channel='Meta' then 'Meta'
    -- When Murad_Marketing_Channel='Google' then 'Google'
    -- When Murad_Marketing_Channel='Affiliate' then 'Affiliate'
    -- else 'Others'
    -- end as Category,
    order_created_at,date_trunc(order_created_at,month) MonthStart,
    DATE_ADD(order_created_at, INTERVAL 52 week) LYD,
   b.Net_Revenue,
    email,
   line_items_quantity,
    Case when sum(net_revenue) over(partition by order_id)=0 then True else false end as retuened_order
    -- ,new_bucket,PromoType
FROM 
    {{ ref('BCAndShopifyData') }} b
    --  left join (select distinct order_id,sku,new_bucket from  {{ ref('PromoType') }}) p     on b.order_id=p.order_id and b.sku=p.sku
-- WHERE 