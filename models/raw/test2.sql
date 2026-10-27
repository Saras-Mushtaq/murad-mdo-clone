WITH BC AS (
  SELECT distinct
    CAST(id AS STRING) AS order_id,
    TRIM(LOWER(sa_email)) AS email,
min(date_created) date
  FROM
    `murad-data-warehouse.Analytics_BigCommerce_Latest.BC_US_V3_Orders`
  WHERE
    LOWER(status) IN ('awaiting fulfillment',
      'awaiting shipment',
      'awaiting pickup',
      'completed',
      'shipped',
      'partially shipped',
      'partially refunded')
    AND DATE(date_created) <= '2024-02-29'
    and trim(CAST(id AS STRING)) is not null and TRIM(LOWER(ba_email)) is not null
group by 1,2
),

SF AS
  (SELECT distinct
  order_id,
  trim(lower(email)) email,
min(date(created_at)) date
FROM
  murad-data-warehouse.Shopify_20240228.US_OrderLines oi
    where date(created_at) between '2024-02-29' and current_date()
    and trim(order_id) is not null and trim(lower(email)) is not null
    and case when order_id in (select distinct order_id from murad-data-warehouse.Shopify_20240228.US_OrderLines where lower(source_name) like '%tiktok%') then 'Tiktok' else 'Non_Tiktok' end = 'Non_Tiktok'
group by 1,2
),

email_order as
(
select distinct order_id,email,case when date = first_order_date then 'New' else 'Existing' end customer_type
from(
 select *,min(date) over(partition by email) first_order_date from 
(select * from SF union all select * from BC))
)
-- select * from email_order where order_id = '3528818'
-- select order_id, count(customer_type) from email_order group by 1

,SF_n AS
  (SELECT
  DATE(created_at) date,
  order_id,
  trim(lower(email)) email,
  COALESCE(oi.discount_applications_code_line_item,oi.discount_applications_code_shipping_line) discount_code,
  oi.line_items_sku AS sku,
  oi.line_items_title AS sku_name,
  coalesce(SUM(CAST(oi.line_items_quantity AS numeric)) - SUM(COALESCE(CAST(oi.refund_line_items_quantity AS numeric),0)),0) line_items_qty,
  coalesce(SUM(CAST(oi.line_items_price AS FLOAT64)),0) line_items_price,
  coalesce(SUM(CAST(oi.refund_line_items_subtotal AS FLOAT64)),0) line_items_refund,
  coalesce(SUM(CAST(oi.line_items_discount_line_item AS FLOAT64)),0) - coalesce(SUM(CAST(oi.shipping_lines_discount_shipping_line AS FLOAT64)),0) line_item_discount,
  sum(coalesce(oi.line_items_price,0)*coalesce(oi.line_items_quantity,0)) - SUM(coalesce(CAST(oi.line_items_discount_line_item AS FLOAT64),0)) - sum(coalesce (refund_line_items_subtotal,0 )) Net_Revenue


FROM
  murad-data-warehouse.Shopify_20240228.US_OrderLines oi
    where date(created_at) between '2024-03-01' and '2025-02-28'
    and case when order_id in (select distinct order_id from murad-data-warehouse.Shopify_20240228.US_OrderLines where lower(source_name) like '%tiktok%') then 'Tiktok' else 'Non_Tiktok' end = 'Non_Tiktok'
    group by 1,2,3,4,5,6
)

,refunded_items as (
select 
distinct order_id,sku,sku_name 
from SF_n
where line_items_qty < 0 
)

,population as(
select a.*except(email),email_order.email new_email,email_order.customer_type customer_type, case when b.sku is not null then 'refunded' else 'non-refunded' end refund_status,
from SF_n a
left join refunded_items b
on a.order_id = b.order_id and a.sku = b.sku
left join email_order
on a.order_id = email_order.order_id
where a.line_items_qty > 0
and 
(
concat(lower(a.sku),lower(a.sku_name)) in (select concat(lower(checkout_sku),lower(checkout_sku_name)) from murad-data-warehouse.BigQuery.checkout_to_fullsize_mapping) 
or
concat(lower(a.sku),lower(a.sku_name)) in (select concat(lower(full_size_sku),lower(full_size_sku_name)) from murad-data-warehouse.BigQuery.checkout_to_fullsize_mapping) 
)
)

,checkout_acquisitions as (
select distinct trim(lower(new_email)) new_email,sku,sku_name,customer_type,checkout_acquisition_date from(
select * ,
min(date) over(partition by trim(lower(new_email)),sku,sku_name) checkout_acquisition_date
from population
where concat(lower(sku),lower(sku_name)) in (select concat(lower(checkout_sku),lower(checkout_sku_name)) from murad-data-warehouse.BigQuery.checkout_to_fullsize_mapping))
where date = checkout_acquisition_date
)

-- select new_email,sku,sku_name,count(customer_type) from checkout_acquisitions group by 1,2,3
,final_population as(
select a.* ,b.checkout_sku,b.checkout_sku_name,
coalesce(b.checkout_sku,a.sku) checkout_sku_adjusted,coalesce(b.checkout_sku_name,a.sku_name) checkout_sku_name_adjusted,
date_diff(date,c.checkout_acquisition_date,day) diff_date,
case
when date_diff(date,c.checkout_acquisition_date,day) < 0 then 'Bought Full Size Before'
when date_diff(date,c.checkout_acquisition_date,day) = 0 and b.checkout_sku is null then 'Bought_Checkout'
-- when date_diff(date,c.checkout_acquisition_date,day) = 0 then 'Bought Full Size After - Same day'
else 'Bought Full Size After'
end attribute,
case
when date_diff(date,c.checkout_acquisition_date,day) < 0 then -2
when date_diff(date,c.checkout_acquisition_date,day) = 0 and b.checkout_sku is null then 2
else 4
end attribute_n,
c.customer_type checkout_customer_type,c.checkout_acquisition_date,
from population a
left join murad-data-warehouse.BigQuery.checkout_to_fullsize_mapping b
on lower(a.sku) = lower(b.full_size_sku) and lower(a.sku_name) = lower(b.full_size_sku_name)
left join checkout_acquisitions c
on lower(a.new_email) = lower(c.new_email) and lower(coalesce(b.checkout_sku,a.sku)) = lower(c.sku) and lower(coalesce(b.checkout_sku_name,a.sku_name)) = lower(c.sku_name)
where 
lower(a.new_email) in (select distinct lower(new_email) from checkout_acquisitions)
)

select * from final_population
where checkout_acquisition_date is not null
-- and
-- not (checkout_sku is null and date > checkout_acquisition_date)