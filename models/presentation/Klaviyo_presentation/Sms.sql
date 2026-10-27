WITH campaign AS (
  (SELECT DISTINCT
    CASE 
      WHEN SAFE.PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/'))
      WHEN SAFE.PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/'))
    END AS Send_date,
    message
    ,'C' as Type
  FROM murad-data-warehouse.BigQuery.Attentive_Campaign)
  UNION ALL
  (
    SELECT DISTINCT
    DATE(NULL) Send_date,
    message,'J' as Type,
  FROM murad-data-warehouse.BigQuery.Attentive_Journey
  )
),

otherdetails AS (
  SELECT
    message_id,
    message_name,
    DATE(TIMESTAMP(timestamp)) AS event_date,
    COUNT(CASE WHEN type = 'MESSAGE_RECEIPT'    THEN type END) AS Received,
    COUNT(CASE WHEN type = 'MESSAGE_LINK_CLICK' THEN type END) AS click
  FROM murad-data-warehouse.BigQuery.Attentive_Eventdate_Data
  WHERE message_id IS NOT NULL
  GROUP BY 1, 2, 3
),

orderdata AS (
  SELECT
    -- message_id,
    message_title,
    DATE(TIMESTAMP(eventdate)) AS event_date,
    SUM(CAST(revenue AS NUMERIC))    AS revenue,
    COUNT(sku)        AS orders
  FROM murad-data-warehouse.BigQuery.Attentive_Indi_conver
  WHERE EventDate !='TOTAL'
  GROUP BY 1, 2
),

-- Merge otherdetails & orderdata on message + date so same-date rows collapse into one
combined AS (
  SELECT
    -- COALESCE(o.message_id,   od.message_id)   AS message_id,
    COALESCE(o.message_name, od.message_title) AS message_name,
    COALESCE(o.event_date,   od.event_date)   AS event_date,
    o.Received,
    o.click,
    od.revenue,
    od.orders
  FROM otherdetails o
  FULL OUTER JOIN orderdata od
    ON  LOWER(o.message_name) = LOWER(od.message_title)
    AND o.event_date          = od.event_date
)
-- bse as(
SELECT
  COALESCE(c.Send_date,cb.event_date) Send_date,
  c.message,
--   c.type as Type,
  -- cb.message_id,

  cb.event_date,
  COALESCE(cb.Received, 0) AS Received,
  COALESCE(cb.click,    0) AS click,
  COALESCE(cb.revenue,  0) AS revenue,
  COALESCE(cb.orders,   0) AS orders,
  Type
FROM campaign c
LEFT JOIN combined cb
  ON LOWER(c.message) = LOWER(cb.message_name)
ORDER BY c.Send_date, cb.event_date
-- )
-- select SUM(RECEIVED),SUM(CLICK),SUM(REVENUE),SUM(ORDERS) from bse where type='F' AND EVENT_DATE BETWEEN '2026-01-4' AND '2026-01-10'
--  GROUP BY 1