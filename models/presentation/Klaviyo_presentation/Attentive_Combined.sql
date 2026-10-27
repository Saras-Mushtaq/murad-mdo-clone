-- SELECT *,'C' AS Message_type FROM `dev_presentation.Sms`
SELECT CASE 
      WHEN SAFE.PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/'))
      WHEN SAFE.PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/'))
    END AS Send_date,message,CASE 
      WHEN SAFE.PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/'))
      WHEN SAFE.PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/'))
    END as event_date,sum(CAST(REPLACE(Delivered, ",", "") AS NUMERIC)) Received,sum(CAST(REPLACE(Clicks, ",", "") AS NUMERIC)) click,sum(CAST(REPLACE(REPLACE(revenue, '$', ''), ',', '') AS FLOAT64)) AS revenue,sum(CAST(REPLACE(conversion, ",", "") AS NUMERIC)) orders,'C' Message_type FROM
    --  `murad-data-warehouse.BigQuery.Attentive_Campaign` 
    (
        (SELECT *, 
        -- case when message in ('050926_20% Off E-Shield Collection','050526_20% Off E-Shield Collection','Mobile Fullscreen - 15% Off [Feb 26]')  then 1 else
  ROW_NUMBER() OVER (
    PARTITION BY DATE2, lower(Message), lower(HasMedia)
    ORDER BY SAFE_CAST(REPLACE(REPLACE(revenue, '$', ''), ',', '')AS FLOAT64) desc,SAFE_CAST(REPLACE(REPLACE(clicks, '$', ''), ',', '') AS FLOAT64) DESC
  ) 
--   end 
  AS rn
FROM (SELECT *,
  CASE 
      WHEN SAFE.PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%Y/%m/%d', REPLACE(`date`, '-', '/'))
      WHEN SAFE.PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/')) IS NOT NULL 
        THEN PARSE_DATE('%m/%d/%Y', REPLACE(`date`, '-', '/'))
    END DATE2
  FROM murad-data-warehouse.BigQuery.Attentive_Campaign)
)
    ) where rn=1
     group by 1,2,3 
union all
(SELECT
  send_date,
  JourneyName,
  event_date,
  SUM(delivered),
  SUM(click),
  SUM(revenue) AS revenue,
  SUM(conversion),
  'J'
FROM (
  SELECT DISTINCT
    Date AS send_date,
    JourneyName,
    Date AS event_date,
    CAST(delivered AS NUMERIC) AS delivered,
    CAST(click AS NUMERIC) AS click,
    CAST(REPLACE(REPLACE(revenue, '$', ''), ',', '') AS FLOAT64) AS revenue,
    CAST(conversion AS NUMERIC) AS conversion
  FROM `murad-data-warehouse.BigQuery.Attentive_Journey`
)

GROUP BY 1, 2, 3)union all
(SELECT
  date,
  CAST(NULL AS STRING),
  date,
  0,
  SUM(CAST(click AS NUMERIC)),
  SUM(revenue),
  SUM(CAST(conversion AS NUMERIC)),
  'AI J'
FROM (
  SELECT date, click, conversion, revenue
  FROM (
    SELECT
      date,
      ROUND(CAST(click AS NUMERIC), 0) AS click,
      ROUND(CAST(REPLACE(REPLACE(revenue, '$', ''), ',', '') AS FLOAT64), 0) AS revenue,
      CAST(conversion AS NUMERIC) AS conversion,
      ROW_NUMBER() OVER (
        PARTITION BY date
        ORDER BY ROUND(CAST(REPLACE(REPLACE(revenue, '$', ''), ',', '') AS FLOAT64), 0) DESC
      ) AS rn
    FROM `murad-data-warehouse.BigQuery.Attentive_AI_Journey`
  )
  WHERE rn = 1
)
GROUP BY 1, 2, 3)