{{ config(
    materialized='table',
    partition_by={
      "field": "order_date",
      "data_type": "date",
      "granularity": "day"
    },
    cluster_by=[ "order_type","customer_type", "order_id", 'sku']
) }}



WITH
BC
AS
(
    SELECT
    case when CAST(id AS STRING) in 
    (
        select ecommerce from(
SELECT  
distinct ecommerce,lower(type) ttype 
FROM `murad-data-warehouse.BigQuery.Recharge_Orders` 
left join unnest(external_order_id) where lower(type)='recurring'

union all

SELECT  
distinct ecommerce,lower(type) ttype
FROM `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders`
left join unnest(external_order_id) a where lower(type)='recurring'
) 
    )then 'Recurring'
    when CAST(concat(id,p_sku) AS STRING) in 
    (
        select concat(ecommerce,sku) from(
SELECT  
distinct ecommerce,purchase_item_type,sku from murad-data-warehouse.BigQuery.Recharge_Orders
left join unnest(external_order_id) left join unnest(line_items) where lower(purchase_item_type)='subscription'

union all

SELECT  
distinct ecommerce,purchase_item_type,sku from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders`
left join unnest(external_order_id) left join unnest(line_items) where lower(purchase_item_type)='subscription'
) 
    )then 'Checkout-Recurring'
   when CAST(id AS STRING) in 
    (
        select ecommerce from(
SELECT  
distinct ecommerce,lower(type) ttype 
FROM `murad-data-warehouse.BigQuery.Recharge_Orders` 
left join unnest(external_order_id) where lower(type)='checkout'

union all

SELECT  
distinct ecommerce,lower(type) ttype
FROM `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders`
left join unnest(external_order_id) a where lower(type)='checkout'
) 
    )then 'Checkout-OTP'
    
     else 
    'OTP' end Platform,
    DATE(date_created) AS order_created_at,
    CAST(id AS STRING) AS order_id,
    ba_email as email,
    c_code AS discount_code,
    p_sku as SKU,
    p_name as SKU_Name,
    p_quantity as line_items_quantity,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) line_items_price,
    -- avg(cast(refunded_amount as numeric)) line_items_refund
    case when p_is_refunded is true then CAST(p_total_ex_tax AS NUMERIC)  - COALESCE(CAST(pad_amount AS NUMERIC), 0) else 0 end as line_items_refund,
    sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) line_item_discount,
    SUM(COALESCE(CAST(p_total_ex_tax AS NUMERIC),0)) - sum(COALESCE(CAST(pad_amount AS NUMERIC), 0)) - sum(cast(p_refund_amount as numeric)) Net_Revenue  
  FROM {{ref("BC_US_Orders" ) }} p
  WHERE LOWER(status) IN ('awaiting fulfillment','awaiting shipment','awaiting pickup','completed','shipped','partially shipped','partially refunded','refunded')
  AND DATE(date_created) <= '2024-02-29'
  group by 1,2,3,4,5,6,7,8,10
),
BCReturned as(
  select
    DATE(date_created) AS order_created_at,
    CAST(id AS STRING) AS order_id,
    p_sku as SKU,
    p_name as SKU_Name,
    -cast(p_quantity_refunded as int64) qnt,
    -(sum(coalesce(CAST(p_total_ex_tax AS NUMERIC),0)  - COALESCE(CAST(pad_amount AS NUMERIC), 0))) as line_items_refund,
  FROM {{ref("BC_US_Orders" ) }} p
  WHERE LOWER(status) IN ('partially refunded','refunded') and p_is_refunded= true
  AND DATE(date_created) <= '2024-02-29'
  group by 1,2,3,4,5
),
SF AS
  (SELECT
  case 
    when order_id in (select distinct order_id from {{ref("Shopify_US_OrderLines")}} where lower(source_name) like '%tiktok%') then 'Tiktok' 
    when concat(order_id,line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%recurring%') and  
(concat(oi.order_id,oi.line_items_sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID

            ) where row_num = 1 and line_items_purchase_item_type='subscription')
) then 'Recurring'
    when concat(order_id,line_items_sku) in (select concat(order_id,line_items_sku) from {{ref("Shopify_US_OrderLines")}}
where lower(tags) like '%subscription%first%order%') then 
( Case when concat(order_id,line_items_sku) in (SELECT concat(order_id,line_items_sku)
        FROM (
            select 
            CAST(EXTERNAL_ORDER_ID.ecommerce as string) as order_id,
            safe_cast(datetime_add(cast( created_at as datetime),interval 0 hour)as TIMESTAMP) as created_at,
            line_items.purchase_item_type as line_items_purchase_item_type,
            line_items.quantity as line_items_quantity,
            line_items.sku as line_items_sku,
            ROW_NUMBER() OVER (PARTITION BY a.id,sku,purchase_item_type order by _daton_batch_runtime desc) row_num
            from `murad-data-warehouse.BigQuery.Murad_US_Recharge_Orders` a
            left join unnest (LINE_ITEMS) LINE_ITEMS       
            left join unnest (EXTERNAL_ORDER_ID) EXTERNAL_ORDER_ID
  
            ) where row_num = 1 and line_items_purchase_item_type='subscription') then 'Checkout-Recurring' else 'Checkout-OTP' END

)
else 'OTP' end Platform,
  DATE(created_at) date_created,
  order_id,
  email,
  COALESCE(oi.discount_applications_code_line_item,oi.discount_applications_code_shipping_line) discount_code,
  oi.line_items_sku AS sku,
  oi.line_items_title AS sku_name,
  coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
  coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
  coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
  coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
  sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue
FROM
  {{ref("Shopify_US_OrderLines")}} oi
    where date(created_at) >= '2024-02-29'  
    -- and order_id not in (select distinct order_id from murad-data-warehouse.Shopify_20240228.US_OrderLines where cancelled_at is not null)
    group by 1,2,3,4,5,6,7
),
final as(
select
  order_id,sku,sku_name,platform order_type,email,order_created_at order_date,discount_code,
    CASE
      WHEN DATE(order_created_at) = first_order_date THEN 'New'
      ELSE 'Existing' end customer_type,line_items_price,sum(Net_Revenue) revenue,sum(line_items_quantity) quantity,
      from 
  (select *, min(order_created_at) over(partition by email) AS first_order_date
  FROM (
  SELECT * FROM BC
  UNION ALL
  SELECT * FROM SF)) group by 1,2,3,4,5,6,7,8,9
),
returned as(
  select * from(
  select Order_date,order_id,sku,sku_name,quantity,revenue from final where quantity<=0 and email is null
  union all
  select * from BCReturned)
)
select *,revenue-returned_revenue as net_revenue from ((select f.*,
case when
lower(trim(discount_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(discount_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes where type = 'Non Recharge')
then 'Promo'
when discount_code is null then null
else 'Loyalty' end Discount_Type,
r.Order_date as returned_date,coalesce(-(r.quantity),0) returned_quantity,coalesce(-(r.revenue),0) as returned_revenue
from (select * from final where quantity>=0 and email is not null) f left join returned r on f.order_id=r.order_id and f.sku=r.sku and f.sku_name=r.sku_name)
union all
(
select
a.amazon_order_id order_id,
SKU,
SPLIT(SKU_name, ' - ')[OFFSET(0)] AS SKU_name,
'Amazon' as Order_type,
Customer,
date(purchase_date) Date,
CAST(NULL AS STRING) as discount_code,
User_type,sum(coalesce(item_price_ex_tax,0)),
sum(coalesce(item_price_ex_tax,0) - coalesce(item_promo_discount,0)) Revenue,
sum(units_sold) as Quantity,
null as discount_type,
null as return_date,
0 as returned_quan,
0 as return_rev
from {{ref('Amazon_order_line')}} a left join (select * from {{ref('amazon_NewExisting_V2')}} where OrderType='Ordered') b on a.amazon_order_id=b.amazon_order_id
  where Sales_Channel = 'US' and order_status != 'Cancelled'
  group by 1,2,3,4,5,6,7,8))
