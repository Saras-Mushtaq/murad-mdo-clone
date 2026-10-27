{{ config(enabled = False) }}


with rawData as(
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
        LEFT JOIN UNNEST(a.attributes) list
        {% if is_incremental() %}
        where _daton_batch_runtime >= (
        select coalesce(max(_daton_batch_runtime), 0) - {{ var('klaviyo_campaigns_lookback', 0) }}
        from {{ this }}
        )
        and list.name is not null
        {% endif %}

    QUALIFY DENSE_RANK() OVER (PARTITION BY a.id ORDER BY a._daton_batch_runtime DESC) = 1
)
select id,name,date
from 
rawData
CROSS JOIN
(SELECT 
date_value AS date
FROM UNNEST(GENERATE_DATE_ARRAY('2022-01-01', CURRENT_DATE(), INTERVAL 1 DAY)) AS date_value) dates 


