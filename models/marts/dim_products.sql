/*
  Product dimension with sales attached.

  Only revenue orders contribute to units_sold, for the same reason as the
  customer dimension: a cancelled order is not a sale.
*/

with products as (
    select * from {{ ref('stg_products') }}
),

sales as (
    select
        items.product_id,
        count(distinct items.order_id)  as orders,
        sum(items.quantity)             as units_sold,
        sum(items.line_total_cents)     as revenue_cents
    from {{ ref('stg_order_items') }} as items
    inner join {{ ref('stg_orders') }} as orders
        on items.order_id = orders.order_id
    where orders.is_revenue
    group by items.product_id
)

select
    products.product_id,
    products.sku,
    products.product_name,
    products.category,
    {{ cents_to_dollars('products.unit_price_cents') }} as unit_price,
    products.is_active,
    coalesce(sales.orders, 0)                           as orders,
    coalesce(sales.units_sold, 0)                       as units_sold,
    {{ cents_to_dollars('coalesce(sales.revenue_cents, 0)') }} as revenue
from products
left join sales on products.product_id = sales.product_id
