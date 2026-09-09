/*
  The daily mart must sum to the same total as the order fact it is built
  from. An aggregate that quietly disagrees with its source is the single
  most expensive kind of bug in a warehouse, because two people quote two
  numbers and neither is obviously wrong.
*/

with daily as (
    select sum(revenue) as revenue from {{ ref('fct_daily_revenue') }}
),

orders as (
    select {{ cents_to_dollars('sum(order_total_cents)') }} as revenue
    from {{ ref('fct_orders') }}
    where is_revenue
)

select daily.revenue as daily_revenue, orders.revenue as order_revenue
from daily
cross join orders
-- A cent of tolerance: the two sides round at different grains.
where abs(daily.revenue - orders.revenue) > 0.01
