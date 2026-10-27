{{ config(enabled = False) }}
--not in use
WITH
BC
AS
(
    SELECT
    'Non_Tiktok' Platform,
    DATE(date_created) AS order_created_at,
    CAST(id AS STRING) AS order_id,
    ba_email as email,
    c_code AS discount_code,
    p_sku as SKU,
    p_name as SKU_Name,
    p_quantity as line_items_quantity,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) line_items_price,
    avg(cast(refunded_amount as numeric)) line_items_refund,
    sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) line_item_discount,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) - sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) - sum(cast(p_refund_amount as numeric)) Net_Revenue  
  FROM `murad-data-warehouse.Analytics_BigCommerce_Latest.BC_US_V3_Orders`
  WHERE LOWER(status) IN ('awaiting fulfillment','awaiting shipment','awaiting pickup','completed','shipped','partially shipped','partially refunded')
  AND DATE(date_created) <= '2024-02-29'
  group by 1,2,3,4,5,6,7,8
),
SF AS
  (SELECT
  case when order_id in (select distinct order_id from murad-data-warehouse.Shopify_20240228.US_OrderLines where lower(source_name) like '%tiktok%') then 'Tiktok' else 'Non_Tiktok' end Platform,
  DATE(created_at) date_created,
  order_id,
  email,
  COALESCE(oi.discount_applications_code_line_item,oi.discount_applications_code_shipping_line) discount_code,
  oi.line_items_sku AS sku,
  oi.line_items_title AS sku_name,
  coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
  coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
  coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
  coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
  sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue

 
FROM
  murad-data-warehouse.Shopify_20240228.US_OrderLines oi
    where date(created_at) >= '2024-02-29'
    group by 1,2,3,4,5,6,7
),
consolidatedview AS (
select
  *,
    CASE
      WHEN DATE(order_created_at) = first_order_date THEN 'New'
      ELSE 'Existing' end type
      from 
  (select *, FIRST_VALUE(DATE(order_created_at)) OVER (PARTITION BY email ORDER BY DATE(order_created_at)) AS first_order_date
  FROM (
  SELECT * FROM BC
  UNION ALL
  SELECT * FROM SF))
),
data as(
 SELECT 
    type AS Type,
    Platform,
    order_created_at,
    SUM(Net_Revenue) AS Net_Revenue,
    Count(distinct email) AS Customer
FROM 
    consolidatedview
WHERE 
    type IN ('New', 'Existing')
GROUP BY 
    1,2,3)
select a.*,b.Net_Revenue as LY_Revenue, b.Customer as LY_Customer
FROM data a
left join data b
on b.order_created_at = DATE_SUB(a.order_created_at, INTERVAL 52 week) and a.type = b.type and a.Platform=b.Platform