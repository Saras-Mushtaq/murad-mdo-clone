-- with newToFile as(
--     select distinct email,order_created_at,'New_to_file' as NewToFileV from {{ref('weekly_report_NewVsExistingV2')}} where type='New' and Platform='Non_Tiktok' AND order_created_at>='2024-08-01'
-- )
{{ config(
    materialized='table',
    partition_by={
      "field": "order_created_at",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["type", "order_id", "Platform"]
) }}

select *,
CASE
    WHEN LAG(order_created_at) OVER (PARTITION BY email ORDER BY order_created_at) IS NULL THEN 'New_to_file'
    WHEN DATE_DIFF(order_created_at,
                   LAG(order_created_at) OVER (PARTITION BY email ORDER BY order_created_at),
                   MONTH) > 12 THEN 'New_to_file'
    ELSE Null
  END AS is_gap_over_12_months

 from {{ref('weekly_report_NewVsExistingV2')}} 
-- a left join  newToFile on a.email=newToFile.email where a.order_created_at>='2024-08-01' and Platform='Non_Tiktok'