/*
  Daily revenue, the table a dashboard actually points at.

  Built from fct_orders rather than from staging so that the definition of
  revenue is inherited rather than restated. Two models each deciding what
  counts as revenue is how a dashboard and a finance report end up
  disagreeing by four percent.

  A table, not a view: it is read far more often than it is written, and it
  is small.
*/

with orders as (
    select * from {{ ref('fct_orders') }}
)

select
    ordered_date,
    count(*)                                              as orders_total,
    count(*) filter (where is_revenue)                    as orders_revenue,
    count(*) filter (where is_cancelled)                  as orders_cancelled,
    count(*) filter (where is_returned)                   as orders_returned,
    count(distinct customer_id) filter (where is_revenue) as customers,
    sum(units) filter (where is_revenue)                  as units,

    {{ cents_to_dollars('sum(order_total_cents) filter (where is_revenue)') }} as revenue,
    {{ cents_to_dollars(
        'sum(order_total_cents) filter (where is_revenue) / nullif(count(*) filter (where is_revenue), 0)'
    ) }} as avg_order_value,

    round(
        count(*) filter (where is_cancelled) * 100.0 / nullif(count(*), 0), 2
    ) as cancellation_rate_pct
from orders
group by ordered_date
