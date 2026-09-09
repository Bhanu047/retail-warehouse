/*
  Per-customer order history.

  Only revenue-bearing orders count toward lifetime value; cancellations
  are counted separately rather than ignored, because the rate is a number
  someone will eventually ask for.
*/

with orders as (
    select * from {{ ref('stg_orders') }}
),

totals as (
    select * from {{ ref('int_order_totals') }}
),

joined as (
    select
        orders.customer_id,
        orders.order_id,
        orders.ordered_at,
        orders.ordered_date,
        orders.is_revenue,
        orders.is_cancelled,
        coalesce(totals.order_total_cents, 0) as order_total_cents,
        coalesce(totals.units, 0)             as units
    from orders
    left join totals on orders.order_id = totals.order_id
)

select
    customer_id,
    count(*)                                                          as orders_total,
    count(*) filter (where is_revenue)                                as orders_revenue,
    count(*) filter (where is_cancelled)                              as orders_cancelled,
    sum(order_total_cents) filter (where is_revenue)                  as lifetime_cents,
    sum(units) filter (where is_revenue)                              as units_total,
    min(ordered_date) filter (where is_revenue)                       as first_order_date,
    max(ordered_date) filter (where is_revenue)                       as latest_order_date
from joined
group by customer_id
