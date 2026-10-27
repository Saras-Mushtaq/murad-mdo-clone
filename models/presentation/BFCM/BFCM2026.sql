WITH
actual_code as
(
with base as
(select
safe_cast(a.id as string) as order_id,
safe_cast(discount_applications.target_type as string) as discount_applications_target_type,
safe_cast(discount_applications.code as string) as discount_applications_code,
from murad-data-warehouse.BigQuery.Murad_US_Shopify_orders a
left join unnest(discount_applications) discount_applications
qualify dense_rank() over (partition by a.id order by _daton_batch_runtime desc) = 1
)
,pre_actual_code as(
select
distinct order_id, discount_applications_code,
case when
lower(trim(discount_applications_code)) in (select distinct lower(code) from murad-data-warehouse.BigQuery.US_Murad_DM_Promo_List_DM_Promo_main)
or lower(trim(discount_applications_code)) in (select distinct lower(code) from `murad-data-warehouse.BigQuery.Discount_codes_Murad___Discount_Codes_Discount_Codes` where type = 'Non Recharge')
then 'Promo'
else 'Loyalty' end type
from base
where lower(trim(discount_applications_target_type)) = 'line_item' and discount_applications_code is not null
)
select
distinct order_id promo_order_id, discount_applications_code
from pre_actual_code
where (lower(discount_applications_code) like '%bf2025%' or lower(discount_applications_code) like '%cyber2025%' OR lower(discount_applications_code) like '%bf2026%' OR lower(discount_applications_code) like '%cyber2026%')
union all
select distinct order_id promo_order_id,max(discount_applications_code) discount_applications_code from pre_actual_code
where type = 'Promo'
and order_id not in
(select
distinct order_id
from pre_actual_code
where (lower(discount_applications_code) like '%bf2025%' or lower(discount_applications_code) like '%cyber2025%' OR lower(discount_applications_code) like '%bf2026%' OR lower(discount_applications_code) like '%cyber2026%'))
group by 1
)
,SF2 as(
select
SF.*,
CASE WHEN order_created_at<'2024-02-29' THEN SF.discount_applications_code ELSE actual_code.discount_applications_code END AS CODE
from (select distinct * from {{ref("weekly_report_NewVsExistingV2")}} ) SF
left join actual_code
on SF.order_id = actual_code.promo_order_id
),
consolidatedview AS (
 select *, case when coalesce(sum(net_revenue) over(partition by order_id,sku,sku_name,order_created_at),0) = 0 then 'Y' else 'N' end Free_Product_Flag,REGEXP_EXTRACT(code, r'(\d+)') as Year,
 TYPE Acq_type
 from(
 SELECT * FROM SF2)

),
fbase as(
select *EXCEPT(line_items_quantity),CASE WHEN Net_Revenue=0 THEN 0 ELSE line_items_quantity END AS line_items_quantity,
-- CASE WHEN YEAR='2025' THEN
 MAX(Day) OVER(PARTITION BY YEAR)  AS MAX_DAY from (
select 
case when lower(Platform) like '%checkout%' then 'Checkout' 
when lower(Platform) like '%non_tiktok%' then 'OTP' 
ELSE Platform end as
Platform,order_id,SKU,SKU_Name,
cast(null as string) as Category, 
order_created_at as date,MonthStart MonthStart,LYD LYD,sum(Net_Revenue) Net_Revenue,ANY_VALUE(IF(email IS NOT NULL, email, NULL)) AS email,sum(line_items_quantity) line_items_quantity,code,
CASE
    WHEN COUNTIF(LOWER(Acq_type) = 'new') > 0 THEN 'New'
    ELSE 'Existing'
  END AS Acq_type,Year,Free_Product_Flag,
case
   when Year='2025' then 3200000
   when Year='2026' then 3150120
end Forecast,
case
   when year = '2025' then date_diff(min(order_created_at),'2025-11-28',day)
   when year = '2026' then date_diff(min(order_created_at),'2026-11-27',day)
end Day,
from consolidatedview where year in('2026','2025') 
and Free_Product_Flag!='Y'  
-- and retuened_order=false
and   (lower(code) like '%bf%' or lower(code) like '%cyber%') 
GROUP BY 1,2,3,4,5,6,7,8,12,Year,Free_Product_Flag,Platform
) where date not between '2025-12-15' and '2026-07-01' 
union all
SELECT 'OTP' AS Platform, NULL AS order_id,  NULL AS SKU,  NULL AS SKU_Name,  'Others' AS Category, DATE '2025-11-14' AS date,  '2025-11-01' AS MonthStart,  '2026-11-14' AS LYD,  0 AS Net_Revenue,  NULL AS email,  'BF2025' AS code,  'New' AS Acq_type, '2025' AS Year, 'N' AS Free_Product_Flag,3200000 AS Forecast,-15 as date_diff,  0 AS line_items_quantity, 15 AS MAX_DAY
union all
SELECT 'OTP' AS Platform, NULL AS order_id,  NULL AS SKU,  NULL AS SKU_Name,  'Others' AS Category, DATE '2025-11-13' AS date,  '2025-11-01' AS MonthStart,  '2026-11-13' AS LYD,  0 AS Net_Revenue,  NULL AS email,  'BF2025' AS code,  'New' AS Acq_type, '2025' AS Year, 'N' AS Free_Product_Flag,3200000 AS Forecast,-14 as date_diff,  0 AS line_items_quantity, 15 AS MAX_DAY
union all
SELECT 'OTP' AS Platform, NULL AS order_id,  NULL AS SKU,  NULL AS SKU_Name,  'Others' AS Category, DATE '2026-11-14' AS date,  '2026-11-01' AS MonthStart,  '2027-11-13' AS LYD,  0 AS Net_Revenue,  NULL AS email,  'BF2026' AS code,  'New' AS Acq_type, '2026' AS Year, 'N' AS Free_Product_Flag,3150120 AS Forecast,-14 as date_diff,  0 AS line_items_quantity, date_diff('2026-11-14','2026-11-27',day) AS MAX_DAY
)
select * from fbase where day<= (select max(day) from fbase where year='2026')

-- - 1