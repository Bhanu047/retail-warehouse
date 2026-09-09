{{ config(materialized='view') }}

/*
  One row per order line, with the line total computed once via a macro so
  that no two models can round it differently.
*/

select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price_cents,
    coalesce(discount_cents, 0)                                                as discount_cents,
    {{ line_total_cents('quantity', 'unit_price_cents', 'discount_cents') }}   as line_total_cents
from {{ source('raw', 'raw_order_items') }}
