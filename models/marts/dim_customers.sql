/*
  Customer dimension, one row per customer, with their order history
  already attached. Wide on purpose -- a BI tool joining three tables to
  answer "how much has this customer spent" is a BI tool nobody uses.
*/

with customers as (
    select * from {{ ref('stg_customers') }}
),

history as (
    select * from {{ ref('int_customer_orders') }}
)

select
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    customers.email,
    customers.has_email,
    customers.country_code,
    customers.signup_date,

    coalesce(history.orders_total, 0)                        as orders_total,
    coalesce(history.orders_revenue, 0)                      as orders_revenue,
    coalesce(history.orders_cancelled, 0)                    as orders_cancelled,
    {{ cents_to_dollars('coalesce(history.lifetime_cents, 0)') }} as lifetime_value,
    coalesce(history.units_total, 0)                         as units_total,
    history.first_order_date,
    history.latest_order_date,

    -- Null when they have never ordered, rather than zero. Zero would sit
    -- in an average and drag it down as though it were a real rate.
    case
        when coalesce(history.orders_total, 0) = 0 then null
        else round(history.orders_cancelled * 100.0 / history.orders_total, 2)
    end                                                      as cancellation_rate_pct,

    coalesce(history.orders_revenue, 0) > 0                  as has_ordered
from customers
left join history on customers.customer_id = history.customer_id
