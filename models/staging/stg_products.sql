{{ config(materialized='view') }}

/*
  One row per product. Prices stay in cents through here -- converting to
  dollars this early would push a rounding decision into every model that
  reads it.
*/

select
    product_id,
    sku,
    product_name,
    category,
    unit_price_cents,
    cast(is_active as boolean)  as is_active,
    cast(updated_at as date)    as updated_at
from {{ source('raw', 'raw_products') }}
