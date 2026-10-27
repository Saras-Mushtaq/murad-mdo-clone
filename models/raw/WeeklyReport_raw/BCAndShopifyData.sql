{{ config(
    materialized='table',
    partition_by={
      "field": "order_created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["type", "order_id", "Platform"]
) }}

WITH
BC
AS
(
    SELECT
    'OTP' Platform,
    'OTP' Platform_v2,
    case when COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)=0 then true else false end as Product_Type,
    DATE(date_created) AS order_created_at,
    CAST(id AS STRING) AS order_id,null order_number,
    ba_email as email,
    -- 'null' as Default_Channel_group,'null' as Source,'null' as medium,'null' Murad_Marketing_Channel,
    c_code AS discount_code,
    p_sku as SKU,
    p_name as SKU_Name,
    p_quantity as line_items_quantity,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) line_items_price,
    avg(cast(refunded_amount as numeric)) line_items_refund,
    sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) line_item_discount,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) - sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) - sum(cast(p_refund_amount as numeric)) Net_Revenue  
  FROM {{ref("BC_US_Orders" ) }} 
  WHERE LOWER(status) IN ('awaiting fulfillment','awaiting shipment','awaiting pickup','completed','shipped','partially shipped','partially refunded')
  AND DATE(date_created) <= '2024-02-29'
  group by 1,2,3,4,5,6,7,8,9,10,11
),
SF AS
  (SELECT
    case 
    when oi.order_id in (select distinct order_id from {{ref("Shopify_US_OrderLines")}}  where lower(source_name) like '%tiktok%') then 'Tiktok' 
    when concat(oi.order_id,oi.line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%recurring%') 
-- and  
-- (concat(oi.order_id,oi.line_items_sku) in (SELECT concat(order_id,line_items_sku)
--         FROM (
--             select 
--             CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
--             safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
--             line_items.purchase_item_type as line_items_purchase_item_type,
--             line_items.quantity as line_items_quantity,
--             line_items.sku as line_items_sku,
--             ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
--             from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
--             left join unnest (LINE_ITEMS) LINE_ITEMS       
--             left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID

--             ) where row_num = 1 and line_items_purchase_item_type='subscription')
-- )
then 'Recurring'
    when concat(oi.order_id,oi.line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%first%order%') then 
( Case when concat(oi.order_id,oi.line_items_sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID

            ) where row_num = 1 and line_items_purchase_item_type='subscription') then 'Checkout-Recurring' else 'Checkout-OTP' END

)
else 'OTP' end Platform_v2,
    case 
    when oi.order_id in (select distinct order_id from {{ref("Shopify_US_OrderLines")}}  where lower(source_name) like '%tiktok%') then 'Tiktok' 
    when concat(oi.order_id,oi.line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%recurring%') and  
(concat(oi.order_id,oi.line_items_sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID

            ) where row_num = 1 and line_items_purchase_item_type='subscription')
)
then 'Recurring'
    when concat(oi.order_id,oi.line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%first%order%') then 
( Case when concat(oi.order_id,oi.line_items_sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID

            ) where row_num = 1 and line_items_purchase_item_type='subscription') then 'Checkout-Recurring' else 'Checkout-OTP' END

)
else 'OTP' end Platform_v2,
  case when free_product=true or gwp_product=true or loyalty_product=true then true else false end Product_Type,
  DATE(created_at) date_created,
  oi.order_id,oi.order_number,
  email,
  -- Default_Channel_group,Source,medium,Murad_Marketing_Channel,
  COALESCE(oi.discount_applications_code_line_item,oi.discount_applications_code_shipping_line) discount_code,
  oi.line_items_sku AS sku,
  oi.line_items_title AS sku_name,
  coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
  coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
  coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
  coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
  sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue

FROM {{ref("Shopify_US_OrderLines")}} oi 
--   left join (select distinct order_id,order_number from murad-data-warehouse.Shopify_20240228.US_OrderLines where order_number is not null) oi2 on oi.order_id=oi2.order_id
  -- left join {{ ref('GA4_Transaction') }} 
  -- t on CAST(order_number AS INT64)=CAST(REPLACE(t.Transaction_id, '#', '') AS INT64)
    where date(created_at) >= '2024-02-29'
    group by 1,2,3,4,5,6,7,8,9,10
),final as(
select
  *,
  -- case when net_revenue<0 then true else false end as rev_per_order,
  -- case when net_revenue=0 then true else false end as free_product,
    CASE
      WHEN DATE(order_created_at) = first_order_date THEN 'New'
      ELSE 'Existing' end type
      from 
  (select b.*,
  -- Murad_Marketing_Channel Murad_Marketing_Channel1,source,
  -- Case when Murad_Marketing_Channel='Unassigned' then coalesce(channel,Murad_Marketing_Channel)
--   when Murad_Marketing_Channel='Direct' then coalesce(channel,Murad_Marketing_Channel)
  -- else 
  -- coalesce(Murad_Marketing_Channel,channel) end as Murad_Marketing_Channel, Case when Murad_Marketing_Channel='Unassigned' then coalesce(channel_final,Murad_Marketing_Channel)
--   when Murad_Marketing_Channel='Direct' then coalesce(channel,Murad_Marketing_Channel)
  -- else 
  -- coalesce(Murad_Marketing_Channel,channel_final) end as Murad_Marketing_Channel_final,channel,
  FIRST_VALUE(DATE(order_created_at)) OVER (PARTITION BY email ORDER BY DATE(order_created_at)) AS first_order_date
  FROM (
  SELECT * FROM BC
  UNION ALL
  SELECT * FROM SF) b
  --  left join 
--   (select distinct * from (SELECT Murad_Marketing_Channel,source, Transaction_id FROM `prod_staging.GA4_Transaction` 
-- union all
-- SELECT Session_Murad_Marketing_Channels,source,Transaction_id FROM `murad-data-warehouse.BigQuery.GA4_Historical`))
  
  -- t
  --  on CAST(order_number AS INT64)=CAST(REPLACE(t.Transaction_id, '#', '') AS INT64) 
--   LEFT JOIN (
--    select orderid,channel,channel_final from (select distinct orderid,channel,channel_final,ROW_NUMBER() OVER (
--             PARTITION BY orderid 
--             ORDER BY LENGTH(channel_final) DESC
--         ) AS rn from(SELECT 
-- DATETIME(TIMESTAMP(occurredat), 'America/Los_Angeles') date, 
-- REGEXP_EXTRACT(orderid, r'[^/]+$') orderid,
-- a.source asr,
-- u.source us,
-- medium,
-- case
-- when lower(medium) = 'text' or lower(medium) = 'sms' or lower(u.source)='attentive' then 'SMS'
-- WHEN lower(medium) = 'affiliate' or lower(u.source) = 'affiliates' THEN 'Affiliates'
-- WHEN lower(medium) = 'email' THEN 'Email'
-- WHEN lower(u.source) = 'facebook' THEN 'Meta'
-- WHEN lower(u.source) = 'google' THEN 'Google'
-- WHEN lower(u.source) = 'bing' THEN 'Bing'
-- WHEN lower(a.source) = 'direct' THEN 'Direct'
-- WHEN lower(medium) = 'display' or lower(u.source) = 'ttd' THEN 'TTD'
-- WHEN lower(a.source) = 'facebook' then 'Meta'
-- WHEN lower(a.source) = 'bing' or lower(a.source) = 'google' THEN 'Organic Search'
-- end as channel,
-- case
-- WHEN lower(medium) IN ('cpc', 'ppc', 'paidsearch') THEN 'Paid Search'
--     WHEN lower(medium) IN ('paidsocial', 'paid_social', 'social_paid') THEN 'Paid Social'
--  WHEN lower(medium) = 'referral' THEN 'Referral'
--  WHEN lower(medium) = 'social' THEN 'Organic Social'
--  WHEN lower(medium) IN ('display', 'banner') THEN 'Display'
-- when lower(medium) = 'text' or lower(medium) = 'sms' or lower(u.source)='attentive' then 'SMS'
-- WHEN lower(medium) = 'affiliate' or lower(u.source) = 'affiliates' THEN 'Affiliates'
-- WHEN lower(medium) = 'email' THEN 'Email'
-- WHEN lower(u.source) = 'bing' THEN 'Bing'
-- WHEN lower(a.source) = 'direct' THEN 'Direct'
-- WHEN lower(medium) = 'display' or lower(u.source) = 'ttd' THEN 'Display'
-- WHEN lower(a.source) = 'bing' or lower(a.source) = 'google' or medium = 'organic' THEN 'Organic Search'
-- end as channel_final
--  FROM `murad-data-warehouse.BigQuery.Murad_US_Shopify_moments_customerJourneySummary` a left join unnest(utmparameters) u 
-- qualify rank() over(partition by id order by _daton_batch_runtime desc)=1)
-- qualify rank() over(partition by orderid order by date desc)=1) where rn=1) scj ON b.order_id= scj.orderid
) 
)
select *except(type),
case when order_id in(select distinct order_id from final where type='New') then 'New' else 'Existing' end as Type
 from final

