{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}

/*
  Order fact, one row per order.

  Incremental because a full rebuild of an order fact is the first thing
  that stops being viable as history grows. The three settings above are
  the ones that matter:

  `unique_key` plus `delete+insert` makes a re-run idempotent. Without a
  unique key, an incremental model appends, and re-running yesterday
  duplicates yesterday.

  The lookback below is the part people leave out. Filtering on
  `> max(ordered_date)` misses any order that arrives late for a day
  already loaded, and nothing ever tells you. Re-processing a trailing
  window costs almost nothing and is only safe because the load replaces
  whole orders rather than appending.

  `on_schema_change='append_new_columns'` so adding a column does not
  require a full refresh, but a removed one still fails loudly.
*/

{% set lookback_days = 3 %}

with orders as (
    select * from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    where ordered_date >= (
        select coalesce(max(ordered_date), '1900-01-01'::date) - interval '{{ lookback_days }} days'
        from {{ this }}
    )
    {% endif %}
),

totals as (
    select * from {{ ref('int_order_totals') }}
),

customers as (
    select customer_id, country_code from {{ ref('stg_customers') }}
)

select
    orders.order_id,
    orders.customer_id,

    -- Orders can arrive before the customer export catches up. Labelling
    -- the gap beats a null that every consumer has to interpret, and beats
    -- an inner join that would silently drop the order entirely.
    coalesce(customers.country_code, 'UNKNOWN')          as country_code,
    customers.customer_id is null                        as is_orphan_order,

    orders.ordered_at,
    orders.ordered_date,
    orders.status,
    orders.is_revenue,
    orders.is_cancelled,
    orders.is_returned,

    coalesce(totals.line_count, 0)                       as line_count,
    coalesce(totals.units, 0)                            as units,
    coalesce(totals.distinct_products, 0)                as distinct_products,
    coalesce(totals.order_total_cents, 0)                as order_total_cents,
    {{ cents_to_dollars('coalesce(totals.order_total_cents, 0)') }} as order_total,
    {{ cents_to_dollars('coalesce(totals.discount_cents, 0)') }}    as discount_total

from orders
left join totals    on orders.order_id = totals.order_id
left join customers on orders.customer_id = customers.customer_id
