with all_combinations as (
  select d.created_at, p.New_Bucket
  from (
    select distinct created_at from {{ ref('PromoType') }}
    union all
    select distinct order_created_at from {{ ref('OldPromo') }}
    ) d
  cross join (select distinct New_Bucket from {{ ref('PromoType') }}) p
),
final as(
  select
  a.created_at created_at,
  a.New_Bucket New_Bucket,
  coalesce(b.net_revenue, 0) as net_revenue
from all_combinations a
left join 
(
    select * from {{ ref('PromoType') }}
    union all
    select * from {{ ref('OldPromo') }}
)
b
  on a.created_at = b.created_at and a.New_Bucket = b.New_Bucket
order by 1, 2
)
select *
from final 
