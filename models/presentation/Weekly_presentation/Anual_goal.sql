with base as(SELECT *
FROM (
  SELECT 
    goals,
    CAST(goalvalue AS FLOAT64) AS value
  FROM murad-data-warehouse.BigQuery.Murad_US_Goal_Murad_Target_Sheet_BQ_Anual_Goal
)
PIVOT (
  MAX(value) FOR goals IN (
    '2026 Revenue Goal (Exluding TTS)' AS revenue_goal_2026,
    '2026 Revenue Goal Stretch (Excluding TTS)' AS revenue_goal_stretch_2026
  )
))
SELECT base.*, rev.Overall_revenue_achieved Overall_revenue
FROM base
CROSS JOIN (
select coalesce(sum(revenue),0) Overall_revenue_achieved from {{ ref('weekly_report_overall') }} where date>='2026-01-01' and platform='Non_Tiktok' ) rev