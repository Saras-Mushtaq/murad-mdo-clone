{{ config(
    materialized='table',
    partition_by={
      "field": "order_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "order_type","customer_type", "order_id", 'sku']
) }}


select order_id,sku,sku_name,order_type,email,order_date,discount_code,customer_type,revenue net_revenue,quantity,Discount_Type from {{ref('SalesOverview')}}
union all
select order_id,sku,sku_name,order_type,null as email,returned_date,discount_code,customer_type,-(returned_revenue),-(returned_quantity),Discount_Type from {{ref('SalesOverview')}}