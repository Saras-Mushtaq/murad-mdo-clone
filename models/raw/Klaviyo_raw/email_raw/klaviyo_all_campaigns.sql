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
where 
list.name is not null
    QUALIFY
        DENSE_RANK() OVER (
            PARTITION BY a.id
            ORDER BY a._daton_batch_runtime DESC
        ) = 1