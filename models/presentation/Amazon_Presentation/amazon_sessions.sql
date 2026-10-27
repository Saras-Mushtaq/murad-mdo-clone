{{ config(
    materialized='table',
    partition_by={
      "field": "date",
      "data_type": "date",
      "granularity": "day"
    }
) }}

 SELECT date date,SUM(SESSIONS) session FROM (SELECT *,dense_rank() over (partition by date order by _daton_batch_runtime desc) as rankm FROM murad-data-warehouse.BigQuery.Amazon_US_SP_SalesAndTrafficReportByDate) where rankm=1 group by 1