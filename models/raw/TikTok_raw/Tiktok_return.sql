SELECT 
Date(DATETIME(TIMESTAMP_SECONDS(CAST(create_time AS INT64)), "America/Los_Angeles")) Return_initiate_date,
Date(DATETIME(TIMESTAMP_SECONDS(CAST(update_time AS INT64)), "America/Los_Angeles")) Return_date,
return_id,
order_id,
return_line_items.product_name product_name,
return_line_items.sku_id sku_id,
return_status,
_daton_batch_runtime,
count(return_line_items.order_line_item_id) returned_quantity,
sum(cast(refund_amount.refund_total as FLOAT64)) returned_amount,
SUM(CAST(refund_amount.refund_subtotal AS FLOAT64)) return_subtotal,
SUM(CAST( refund_amount.refund_shipping_fee AS FLOAT64)) refund_shipping_fee,
SUM(CAST(refund_amount.retail_delivery_fee AS FLOAT64)) retail_delivery_fee
-- sum(cast(`return_line_items`[SAFE_OFFSET(0)].`refund_amount`[SAFE_OFFSET(0)].refund_total as FLOAT64)) returned_amount,
-- SUM(CAST(`return_line_items`[SAFE_OFFSET(0)].`refund_amount`[SAFE_OFFSET(0)].refund_subtotal AS FLOAT64)) return_subtotal,
-- SUM(CAST( `return_line_items`[SAFE_OFFSET(0)].`refund_amount`[SAFE_OFFSET(0)].refund_shipping_fee AS FLOAT64)) refund_shipping_fee,
-- SUM(CAST(`return_line_items`[SAFE_OFFSET(0)].`refund_amount`[SAFE_OFFSET(0)].retail_delivery_fee AS FLOAT64)) retail_delivery_fee
FROM
-- (select * from 
`murad-data-warehouse.BigQuery.murad_us_tiktok_shop_Returns` 
LEFT JOIN
UNNEST(return_line_items) return_line_items
left join
Unnest(return_line_items.refund_amount) as refund_amount
where return_status!='RETURN_OR_REFUND_REQUEST_CANCEL' 
group by 1,2,3,4,5,6,7,8
QUALIFY DENSE_RANK() OVER(PARTITION BY return_id ORDER BY _daton_batch_runtime DESC) = 1