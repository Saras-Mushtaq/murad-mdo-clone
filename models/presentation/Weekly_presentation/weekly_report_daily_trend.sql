WITH
consolidatedview as
(
select 
order_created_at,
count(distinct case when net_revenue >= 0 then order_id end) total_orders,
sum(net_revenue) revenue
from {{ ref('BCAndShopifyData') }}
group by 1
)

select 
a.*,b.total_orders LY_Orders,b.revenue LY_revenue
from consolidatedview a
join consolidatedview b
on b.order_created_at = DATE_SUB(a.order_created_at, INTERVAL 52 week)




