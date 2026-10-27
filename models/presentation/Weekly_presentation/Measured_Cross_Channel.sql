{{ config(
    materialized='table',
    partition_by={
      "field": "day",
      "data_type": "date_time",
      "granularity": "day"
    },
    cluster_by=["ad_platform","channel"]
) }}

WITH latest_run AS (
    SELECT
        date(day) day,
        MAX(run_id) AS max_run_id
    FROM murad-data-warehouse.Measured_Dataset.cross_channel
    GROUP BY date(day)
)

SELECT
    t.* EXCEPT (
        media_spend,
        total_spend,
        platform_orders,
        platform_sales,
        adjustment_factor,
        incremental_orders,
        incremental_sales
    ),

    SAFE_CAST(media_spend AS FLOAT64) AS media_spend,
    SAFE_CAST(total_spend AS FLOAT64) AS total_spend,
    SAFE_CAST(platform_orders AS FLOAT64) AS platform_orders,
    SAFE_CAST(platform_sales AS FLOAT64) AS platform_sales,
    SAFE_CAST(adjustment_factor AS FLOAT64) AS adjustment_factor,
    SAFE_CAST(incremental_orders AS FLOAT64) AS incremental_orders,
    SAFE_CAST(incremental_sales AS FLOAT64) AS incremental_sales

FROM murad-data-warehouse.Measured_Dataset.cross_channel t
JOIN latest_run lr
    ON date(t.day) = lr.day
   AND t.run_id = lr.max_run_id