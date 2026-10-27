{{ config(
    materialized='table',
    partition_by={
      "field": "date_created",
      "data_type": "DATETIME",
      "granularity": "day"
    },
    cluster_by=[ "p_sku"]
) }}


SELECT * EXCEPT(row_n)
FROM
(SELECT a.* except(billing_address, products, shipping_addresses, coupons,metafields, date_created, date_modified,date_shipped),refunded_amount as new_refunded_amount,
  DATETIME(a.date_created ,"America/Los_Angeles") date_created,
  DATETIME(a.date_modified ,"America/Los_Angeles") date_modified,
  DATETIME( cast((case
  when a.date_shipped = '' then null
  when length(a.date_shipped) = 20 then a.date_shipped
  else concat(left(a.date_shipped,16),':00Z')
  end) as timestamp),"America/Los_Angeles") date_shipped,

  --billing_addresses
  ba.first_name AS ba_first_name, 
  ba.last_name AS ba_last_name, 
  ba.company AS ba_company, 
  ba.street_1 AS ba_street_1, 
  ba.street_2 AS ba_street_2, 
  ba.city AS ba_city, 
  ba.state AS ba_state, 
  ba.zip ba_zip, 
  ba.country ba_country, 
  ba.country_iso2 AS ba_country_iso2, 
  ba.phone AS ba_phone, 
  ba.email AS ba_email, 

  --billing addresses form fields
  baff.name baff_name,
  baff.value baff_value,

  --products
  p.id p_id,
  p.order_id p_order_id,
  p.product_id p_product_id,
  p.variant_id p_variant_id, 
  p.order_address_id p_order_address_id,
  p.name p_name,
  p.name_customer p_name_customer,
  p.name_merchant p_name_merchant,
  p.sku p_sku,
  p.upc p_upc,
  p.type p_type,
  p.base_price p_base_price,
  p.price_ex_tax p_price_ex_tax,
  p.price_inc_tax p_price_inc_tax,
  p.price_tax p_price_tax,
  p.base_total P_base_total,
  p.total_ex_tax p_total_ex_tax,
  p.total_inc_tax p_total_inc_tax,
  p.total_tax p_total_tax,
  p.weight p_weight,
  p.width p_width,
  p.height p_height,
  p.depth p_depth,
  p.quantity p_quantity,
  p.base_cost_price p_base_cost_price,
  p.cost_price_inc_tax p_cost_price_inc_tax,
  p.cost_price_ex_tax p_cost_price_ex_tax,
  p.cost_price_tax p_cost_price_tax,
  p.is_refunded p_is_refunded,
  p.quantity_refunded p_quantity_refunded,
  p.refund_amount p_refund_amount,
  p.return_id p_return_id,
  p.wrapping_name p_wrapping_name, 
  p.base_wrapping_cost p_base_wrapping_cost,
  p.wrapping_cost_ex_tax p_wrapping_cost_ex_tax,
  p.wrapping_cost_inc_tax p_wrapping_cost_inc_tax,
  p.wrapping_cost_tax p_wrapping_cost_tax,
  p.wrapping_message p_wrapping_message,
  p.quantity_shipped p_quantity_shipped,
  p.event_date p_event_date,
  p.fixed_shipping_cost p_fixed_shipping_cost,
  p.ebay_item_id p_ebay_item_id,
  p.ebay_transaction_id p_ebay_transaction_id,
  p.is_bundled_product p_is_bundled_product,
  p.bin_picking_number p_bin_picking_number,
  p.fulfillment_source p_fulfillment_source,
  p.url p_url,
  p.resource p_resource,
  p.brand p_brand,

  -- products_applied_discounts
  pad.id pad_id,
  pad.amount pad_amount,
  pad.name pad_name,
  pad.code pad_code,
  pad.target pad_target,

    --products_product_options
  ppo.id ppo_id,
  ppo.option_id ppo_option_id,
  ppo.order_product_id ppo_order_product_id,
  ppo.product_option_id ppo_product_option_id,
  ppo.display_name ppo_display_name,
  ppo.display_name_merchant ppo_display_name_merchant,
  ppo.display_value ppo_display_value,
  ppo.display_value_customer ppo_display_value_customer,
  ppo.display_value_merchant ppo_display_value_merchant,
  ppo.value ppo_value,
  ppo.type ppo_type,
  ppo.name ppo_name,
  ppo.display_style ppo_display_style,


  --shipping_addresses
  sa.id sa_id, 
  sa.order_id sa_order_id, 
  sa.first_name sa_first_name, 
  sa.last_name sa_last_name, 
  sa.company sa_company, 
  sa.street_1 sa_street_1, 
  sa.street_2 sa_street_2, 
  sa.city sa_city, 
  sa.zip sa_zip, 
  sa.country sa_country, 
  sa.country_iso2 sa_country_iso2, 
  sa.state sa_state, 
  sa.email sa_email, 
  sa.phone sa_phone, 
  sa.items_total sa_items_total, 
  sa.items_shipped sa_items_shipped, 
  sa.shipping_method sa_shipped_method, 
  sa.base_cost sa_base_cost,
  sa.cost_ex_tax sa_cost_ex_tax,
  sa.cost_inc_tax sa_cost_inc_tax,
  sa.cost_tax sa_cost_tax, 
  sa.cost_tax_class_id sa_cost_tax_class_id, 
  sa.base_handling_cost sa_base_handling_cost, 
  sa.handling_cost_ex_tax sa_handling_cost_ex_tax, 
  sa.handling_cost_inc_tax sa_handling_cost_inc_tax,
  sa.handling_cost_tax sa_handling_cost_tax,
  sa.handling_cost_tax_class_id sa_handling_cost_tax_class_id,
  sa.shipping_zone_id sa_shipping_zone_id,
  sa.shipping_zone_name sa_shipping_zone_name,
  sa.url sa_url,
  sa.resource sa_resource,

  --shipping addresses form fields
  saff.name,
  saff.value,

  --shipping_quotes
  sq.id sq_id,
  sq.uuid sq_uuid,
  sq.timestamp sq_timestamp,
  sq.shipping_provider_id sq_shipping_provider_id,
  sq.provider_code sq_provider_code,
  sq.carrier_code sq_carrier_code,
  sq.rate_code sq_rate_code,
  sq.rate_id sq_rate_id,

  --coupons
  c.id c_id, 
  c.coupon_id c_coupon_id,
  c.order_id c_order_id, 
  c.code c_code, 
  c.amount c_amount, 
  c.type c_type, 
  c.discount c_discount, 
  c.url c_url,
  c.resource c_resource,

  --metafields
  m.id m_id,
  m.key m_key,
  m.value m_value,
  m.namespace m_namespace,
  m.permission_set m_permission_set,
  m.resource_type m_resource_type,
  m.resource_id m_resource_id,
  m.description m_description,
  m.date_created m_date_created,
  m.date_modified m_date_modified,

  row_number() over(partition by a.id, p.product_id order by a._daton_batch_runtime desc) as row_n

FROM `murad-data-warehouse.BigQuery.BC_US_V3_orders` a
left join unnest(billing_address) ba
LEFT join unnest(ba.form_fields) baff
Left join unnest(products) p
left join unnest(p.applied_discounts) pad
left join unnest(p.product_options) as ppo
left join unnest(shipping_addresses) sa
left join unnest(sa.form_fields) saff
left join unnest(sa.shipping_quotes) sq
left join unnest(coupons) c
left join unnest(metafields) m
)
where row_n = 1