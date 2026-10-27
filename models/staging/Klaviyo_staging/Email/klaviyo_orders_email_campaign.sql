select date Event_Date,attribution_message ID,
attribution_flow flow_ID,'Email' as Channel,
sum(orders) Orders,sum(rev) Revenue from (select
date(base.date) date,attribution_message,attribution_flow,dated.name name,
count( order_id) orders,
sum(coalesce(rev,0)) rev
from(
select
date,
attribution_message,
attribution_flow,
order_id,
event_properties_value rev
from
{{ ref('Klaviyo_orders') }}
where attributed_channel is null or attributed_channel='$email_channel'
order by 1 

) base left join
(
 SELECT 
    id, 
    name, 
    created, 
    updated
FROM (
    SELECT
        a.id AS id,
        list.name AS name,
        list.created_at AS created,
        list.updated_at AS updated,
        a._daton_user_id AS _daton_user_id,
        a._daton_batch_runtime AS _daton_batch_runtime,
        a._daton_batch_id AS _daton_batch_id
    FROM 
        murad-data-warehouse.BigQuery.Klaviyo_Integration_US_campaigns a
    LEFT JOIN 
        UNNEST(a.attributes) list
    WHERE list.name IS NOT NULL
    QUALIFY 
        DENSE_RANK() OVER (
            PARTITION BY a.id
            ORDER BY a._daton_batch_runtime DESC
        ) = 1
)
) dated on base.attribution_message=dated.id 

-- where date(dated.updated) between '2025-01-19' and '2025-01-25'
group by  1,2,3,4
)
-- where name is not null 
group by 1,2,3,4
