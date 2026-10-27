{{ config(
    materialized='table',
    partition_by={
      "field": "inventory_item_id",
      "data_type": "String",
    },
    cluster_by=[ "sku","location_id", "warehouse_name"]
) }}

select a.inventory_item_id,sku,a.location_id,name as warehouse_name,available,a.updated_at,inventory_update_rank
from
(
  select  inventory_item_id,location_id,available,updated_at,rank() over (partition by inventory_item_id,location_id order by updated_at asc)  inventory_update_rank 
  from (select distinct inventory_item_id,location_id,available,updated_at from murad-data-warehouse.BigQuery.Murad_US_Shopify_inventory_levels) 
  order by 1,2,5
) a
 left join
(
 select  * from murad-data-warehouse.BigQuery.Murad_US_Shopify_inventory_items where sku!='' qualify rank() over (partition by id order by _daton_batch_runtime,_daton_batch_id desc)=1
) b on a.inventory_item_id=b.id
 left join
(
  select * from murad-data-warehouse.BigQuery.Murad_US_Shopify_locations qualify rank() over (partition by id order by _daton_batch_runtime desc)=1
) c on a.location_id=c.id