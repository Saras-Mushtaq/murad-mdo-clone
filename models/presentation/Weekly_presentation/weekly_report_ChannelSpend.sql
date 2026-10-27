{{ config(enabled = False) }}

SELECT 
  MonthStartDate,
  channel,
  spend
FROM 
(
  SELECT
    MonthStartDate,
    CAST(TTD AS FLOAT64) AS TTD,
    CAST(Bing AS FLOAT64) AS Bing,
    CAST(Affiliate AS FLOAT64) AS Affiliate,
    -- CAST(YouTube AS FLOAT64) AS YouTube,
    CAST(Meta AS FLOAT64) AS Meta,
    CAST(Google AS FLOAT64) AS Google from {{ ref('MontlyGoal') }})
UNPIVOT (
  spend FOR channel IN (TTD, Bing, Affiliate, Meta, Google)
)