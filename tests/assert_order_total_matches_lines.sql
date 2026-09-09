/*
  The order total must equal the sum of its lines.

  This is the test that catches a join fanning out. If a duplicate crept
  back into stg_customers, or int_order_totals grouped on the wrong key,
  the totals and the lines would diverge -- and nothing else here would
  notice, because both numbers would still be non-null and positive.

  A singular test rather than a generic one: it asserts a relationship
  between two models, which no column-level test can express.
*/

with from_fact as (
    select order_id, order_total_cents
    from {{ ref('fct_orders') }}
),

from_lines as (
    select order_id, sum(line_total_cents) as line_total_cents
    from {{ ref('stg_order_items') }}
    group by order_id
)

select
    from_fact.order_id,
    from_fact.order_total_cents,
    from_lines.line_total_cents
from from_fact
inner join from_lines using (order_id)
where from_fact.order_total_cents != from_lines.line_total_cents
