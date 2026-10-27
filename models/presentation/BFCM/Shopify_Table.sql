with base as(select *,
case
   when EXTRACT(YEAR FROM order_created_at) = 2024 then date_diff(order_created_at,'2024-11-29',day)
   when EXTRACT(YEAR FROM order_created_at) = 2025 then date_diff(order_created_at,'2025-11-28',day)
end Day,EXTRACT(YEAR FROM order_created_at) year
 from {{ref("weekly_report_NewVsExistingV2")}} where order_created_at between '2024-11-14' and '2024-12-15' or order_created_at between '2025-11-13' and CURRENT_DATE("America/Los_Angeles")-1)
 select * from base where Day<=(select max(day) from base where EXTRACT(YEAR FROM order_created_at) = 2025) and PRODUCT_TYPE=FALSE AND Net_Revenue!=0
--  and free_product=false
-- and retuened_order=false