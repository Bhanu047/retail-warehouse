/*
  Order totals rolled up from lines.

  Ephemeral: it is joined by two marts and never queried directly, so
  materialising it would add a table nobody reads. dbt inlines it as a CTE
  into each consumer instead.
*/

select
    order_id,
    count(*)                        as line_count,
    sum(quantity)                   as units,
    sum(line_total_cents)           as order_total_cents,
    sum(discount_cents)             as discount_cents,
    count(distinct product_id)      as distinct_products
from {{ ref('stg_order_items') }}
group by order_id
