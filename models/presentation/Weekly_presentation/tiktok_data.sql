{{ config(
    materialized='table',
    partition_by={
      "field": "date_created",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["sku","sku_name"]
) }}

SELECT 
order_created_at date_created,
order_id,
trim(lower(email)) email,
-- discount_applications_code code,
sku,
sku_name,
platform,
line_items_quantity line_items_qty,
line_items_price,
line_items_refund,
line_item_discount,
Net_Revenue

FROM {{ref('BCAndShopifyData')}}
WHERE platform='Tiktok' AND NET_REVENUE!=0

--OLD CODE
-- -- With Tiktok_Email_Replacing_Mech as
-- -- (
-- --   with Tiktok_Emails as
-- -- (
-- --  select concat(trim(lower(customer_first_name)),trim(lower(customer_last_name)),trim(lower(shipping_address_zip))) unique_code from murad-data-warehouse.Shopify_20240228.US_OrderLines
-- --  where lower(source_name) like '%tiktok%'
-- -- )

-- -- ,Non_Tiktok_Emails as
-- -- (
-- --   (select distinct concat(trim(lower(customer_first_name)),trim(lower(customer_last_name)),trim(lower(shipping_address_zip))) unique_code,
-- -- lower(trim(email)) email
-- -- from murad-data-warehouse.Shopify_20240228.US_OrderLines
-- --  where lower(source_name) not like '%tiktok%')

-- --  union all

-- --  (SELECT  
-- -- distinct concat(trim(lower(sa_first_name)),trim(lower(sa_last_name)),trim(lower(sa_zip))),trim(lower(sa_email)) email
-- -- FROM `murad-data-warehouse.Analytics_BigCommerce_Latest.BC_US_V3_Orders` )
-- -- )

-- -- select distinct a.unique_code,Email from Tiktok_Emails a
-- -- join Non_Tiktok_Emails b
-- -- on a.unique_code = b.unique_code

-- -- ),

-- With SF AS
--   (SELECT
--   DATE(created_at) date_created,
--   order_id,
--   trim(lower(oi.email)) email,
--   COALESCE(oi.discount_applications_code_line_item,oi.discount_applications_code_shipping_line) discount_code,
--   oi.line_items_sku AS sku,
--   oi.line_items_title AS sku_name,
--   case
--   when order_id in (select distinct order_id from murad-data-warehouse.Shopify_20240228.US_OrderLines
-- where lower(source_name) like '%tiktok%') then 'Tiktok'
--   when concat(order_id,line_items_sku) in (select concat(order_id,line_items_sku) from murad-data-warehouse.Shopify_20240228.US_OrderLines
-- where lower(tags) like '%subscription%')  then 'Subscription' 
--   else 'Otp'
--   end platform,
--   coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
--   coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
--   coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
--   coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
--   sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue
 
-- FROM
--   (select *, 
--   concat(trim(lower(customer_first_name)),trim(lower(customer_last_name)),trim(lower(shipping_address_zip))) unique_code
--   from murad-data-warehouse.Shopify_20240228.US_OrderLines 
--     where date(created_at) >= '2024-02-29') oi
--     -- left join Tiktok_Email_Replacing_Mech b
--     -- on oi.unique_code = b.unique_code
--     where order_id in (select distinct order_id from murad-data-warehouse.Shopify_20240228.US_OrderLines
-- where lower(source_name) like '%tiktok%')
--     group by 1,2,3,4,5,6,7
-- )

-- -- list_of_sf_return_emails as(
-- -- select distinct order_id n_order_id,trim(lower(email)) n_email from SF 
-- -- where trim(lower(email)) is not null
-- -- )

-- select
-- date_created,
-- order_id,
-- trim(lower(email)) email,
-- -- discount_applications_code code,
-- sku,
-- sku_name,
-- platform,
-- line_items_qty,
-- line_items_price,
-- line_items_refund,
-- line_item_discount,
-- Net_Revenue
-- from SF
-- -- left join list_of_sf_return_emails
--     -- on SF.order_id = list_of_sf_return_emails.n_order_id
-- where Net_Revenue!=0 
-- and order_id='6658273181999'