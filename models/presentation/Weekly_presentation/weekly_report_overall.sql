{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["platform"]
) }}


-- SELECT 
-- platform,order_created_at as date,
-- count(distinct case when net_revenue>0 then  order_id end) orders,sum(net_revenue) revenue,sum( case when net_revenue!=0 then line_items_quantity end) quantity FROM {{ref('BCAndShopifyData')}}
-- group by 1,2 

-- old query
WITH Qty2024 AS (
  WITH BC_new AS (
    SELECT
      DATE(date_created) AS date,
      CAST(id AS STRING) AS order_id,
      p_sku AS SKU,
      p_name AS SKU_Name,
      CASE
        WHEN LOWER(p_name) LIKE '%pto%' THEN SUBSTRING(p_name, 6, 6)
        ELSE p_sku
      END AS sku2,
      p_quantity AS line_items_quantity,
      SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC), 0)) AS line_items_price,
      AVG(CAST(refunded_amount AS NUMERIC)) AS line_items_refund,
      SUM(COALESCE(CAST(pad_amount AS NUMERIC), 0)) AS line_item_discount,
      SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC), 0)) 
        - SUM(COALESCE(CAST(pad_amount AS NUMERIC), 0)) 
        - SUM(CAST(p_refund_amount AS NUMERIC)) AS Net_Revenue
    FROM {{ref("BC_US_Orders" ) }} 
    WHERE LOWER(status) IN (
      'awaiting fulfillment', 'awaiting shipment', 'awaiting pickup', 
      'completed', 'shipped', 'partially shipped', 'partially refunded'
    )
    AND DATE(date_created) BETWEEN '2022-01-01' AND '2024-02-29'
    GROUP BY 1, 2, 3, 4, 5, 6
  ),
  base AS (
    SELECT 
      date,
      sku2,
      CASE 
        WHEN sku2 LIKE '%PTO%' THEN sku2
        ELSE sku_name
      END AS sku_name,
      SUM(
        CASE
          WHEN sku2 LIKE '%PTO%' AND line_items_quantity = 0 THEN 1
          WHEN sku2 LIKE '%PTO%' AND line_items_quantity != 0 THEN 0
          ELSE line_items_quantity
        END
      ) AS line_items_quantity,
      SUM(net_revenue) AS net_revenue
    FROM BC_new
    GROUP BY 1, 2, 3
  )
  SELECT Platform, date, SUM(line_items_quantity) AS Net_Quantity
  FROM (
    SELECT
      'Non_Tiktok' AS Platform,
      date,
      sku2,
      sku_name,
      SUM(line_items_quantity) AS line_items_quantity,
      SUM(net_revenue) AS net_revenue
    FROM base
    GROUP BY 1, 2, 3, 4
    HAVING net_revenue != 0
  )
  GROUP BY 1, 2
),
BC AS (
  SELECT
    'Non_Tiktok' AS Platform,
    DATE(date_created) AS date,
    COUNT(DISTINCT TRIM(CAST(id AS STRING))) AS orders,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC), 0)) 
      - SUM(COALESCE(CAST(pad_amount AS NUMERIC), 0)) 
      - SUM(CAST(p_refund_amount AS NUMERIC)) AS Net_Revenue
  FROM {{ref("BC_US_Orders" ) }} 
  WHERE LOWER(status) IN (
    'awaiting fulfillment', 'awaiting shipment', 'awaiting pickup', 
    'completed', 'shipped', 'partially shipped', 'partially refunded'
  )
  AND DATE(date_created) BETWEEN '2022-01-01' AND '2024-02-29'
  GROUP BY 1, 2
),
SF AS (
  SELECT 
    platform,
    date,
    COUNT(DISTINCT CASE WHEN net_revenue > 0 THEN order_id END) AS orders, 
    SUM(net_revenue) AS net_revenue,
    SUM(net_quantity) AS net_quantity
  FROM (
    SELECT *, 
      CASE 
        WHEN SUM(Net_Revenue) OVER (PARTITION BY order_id,platform,sku, sku_name, date) <> 0 THEN line_items_qty
        ELSE 0 
      END AS net_quantity
    FROM (
      SELECT
        CASE 
          WHEN order_id IN (
            SELECT DISTINCT order_id 
            FROM {{ref('Shopify_US_OrderLines' ) }}  
            WHERE LOWER(source_name) LIKE '%tiktok%'
          ) THEN 'Tiktok' 
          ELSE 'Non_Tiktok' 
        END AS Platform,
        DATE(created_at) AS date,
        order_id,
        oi.line_items_sku AS sku,
        oi.line_items_title AS sku_name,
        SUM(COALESCE(CAST(oi.line_items_quantity AS NUMERIC), 0)) 
          - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS NUMERIC), 0)) AS line_items_qty,
        SUM(
          COALESCE(oi.line_items_price, 0) * COALESCE(oi.line_items_quantity, 0)
        ) 
        - SUM(COALESCE(CAST(oi.line_items_discount_line_item AS FLOAT64), 0)) 
        - SUM(COALESCE(refund_line_items_subtotal, 0)) AS Net_Revenue
      FROM {{ref("Shopify_US_OrderLines" ) }}  oi
      WHERE DATE(created_at) >= '2024-02-29'
      GROUP BY 1, 2, 3, 4, 5
    )
  ) 
  GROUP BY 1, 2
),
consolidated AS (
  SELECT 
    platform, 
    date, 
    SUM(orders) AS orders, 
    SUM(Net_Revenue) AS revenue, 
    SUM(net_quantity) AS quantity
  FROM (
    SELECT BC.*, net_quantity FROM BC 
    LEFT JOIN Qty2024 ON BC.date = Qty2024.date
    UNION ALL
    SELECT * FROM SF
  ) 
  GROUP BY 1, 2
)
SELECT a.*
    --    b.revenue AS LY_revenue, 
    --    b.orders AS LY_orders, 
    --    b.quantity AS LY_quantity
FROM consolidated a
-- LEFT JOIN consolidated b
-- ON b.date = DATE_SUB(a.date, INTERVAL 52 WEEK) and a.platform=b.platform