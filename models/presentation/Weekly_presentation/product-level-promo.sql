{{ config(
    materialized='table',
    partition_by={
      "field": "Date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=["order_id","code"]
) }}

with
BC AS
(
    SELECT
    DATE(date_created) AS date,
    CAST(id AS STRING) AS order_id,
    trim(lower(sa_email)) as email,
    -- c_code AS code,
    case when
lower(trim(c_code)) in (select distinct lower(trim(code)) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(c_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes)
then lower(trim(c_code))
else null
end code,
    p_sku as SKU,
    p_name as SKU_Name,
    p_quantity as line_items_quantity,
    case when lower(m_namespace) like '%recharge%' then 'Subscription' else 'Otp' end Platform,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) line_items_price,
    sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) line_item_discount,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) - sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) - sum(cast(p_refund_amount as numeric)) Net_Revenue,
    0 as returned_quantity,avg(cast(refunded_amount as numeric)) line_items_refund,
    date(null) as return_date
  FROM {{ref("BC_US_Orders" ) }} 
  WHERE LOWER(status) IN ('awaiting fulfillment','awaiting shipment','awaiting pickup','completed','shipped','partially shipped','partially refunded')
  group by 1,2,3,4,5,6,7,8
), orders as(
SELECT
  DATE(TIMESTAMP(created_at), "America/Los_Angeles") created_at,
  SAFE_CAST(a.id AS STRING) AS order_id,email,
  case when lower(SAFE_CAST(discount_app.code AS STRING)) like '%wsms%' then 'WELCOMESMS' else SAFE_CAST(discount_app.code AS STRING) end as discount_applications_code,
--   SAFE_CAST(discount_app.code AS STRING) AS discount_applications_code,
  l.sku,
  l.name,
  cast(l.quantity as float64) quantity,
  case
  when lower(source_name) like '%tiktok%' then 'Tiktok'
  when lower(tags) like '%subscription%'  then 'Subscription'
  else 'Otp'
  end platform,
  cast(l.price as float64) price,
  cast(d.amount as float64) discount,
  -- safe_cast(discount_app.target_type as string) as discount_applications_target_type,
  d.discount_application_index,
  cast(l.quantity as float64)*cast(l.price as float64)-cast(d.amount as float64) net_revenue
FROM murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
LEFT JOIN UNNEST(a.discount_applications) AS discount_app WITH OFFSET AS discount_offset ON TRUE
LEFT JOIN UNNEST(a.line_items) AS l
LEFT JOIN UNNEST(l.discount_allocations) AS d
WHERE discount_offset=d.discount_application_index
QUALIFY DENSE_RANK() OVER (PARTITION BY a.id ORDER BY _daton_batch_runtime DESC) = 1
),
return as(
  SELECT
 safe_cast(order_id as string) order_id,DATE(TIMESTAMP(created_at), "America/Los_Angeles") created_at,r.quantity,l.sku,l.name,COALESCE(SAFE_CAST(r.subtotal AS FLOAT64), 0) returned,d.discount_application_index discount_application_index
FROM murad-data-warehouse.BigQuery.Murad_US_Shopify_refunds a
LEFT JOIN UNNEST(refund_line_items) AS r
LEFT JOIN UNNEST(r.line_item) AS l
LEFT JOIN UNNEST(l.discount_allocations) AS d
QUALIFY DENSE_RANK() OVER (PARTITION BY a.id ORDER BY _daton_batch_runtime DESC) = 1
),SF as(
select a.* except(discount_application_index),b.quantity returned_quantity,b.returned,b.created_at return_date,
case when
lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes )  or lower(trim(discount_applications_code))='welcomesms'
then 'Promo'
else 'Loyalty' end type
 from orders a left join return b on
a.order_id=b.order_id and a.sku=b.sku and a.discount_application_index=b.discount_application_index and  net_revenue=returned),
base as(
SELECT * FROM(
 SELECT * FROM BC
  UNION ALL
  SELECT * EXCEPT(TYPE) FROM SF WHERE TYPE='Promo')
)
select order_id,code,date,line_items_quantity,net_revenue from base
union all
select order_id,code,return_date,-(returned_quantity),-(line_items_refund) from base
