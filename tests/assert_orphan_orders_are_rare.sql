/*
  Orders referencing an unknown customer are expected -- exports lag. A lot
  of them is not: it means the customer feed has broken.

  So this is a threshold rather than a `relationships` test. A hard
  referential test here would fail every day for a condition that is
  normal, and a test that always fails is a test everyone learns to ignore.
*/

select
    count(*) as orphan_orders,
    count(*) * 100.0 / (select count(*) from {{ ref('fct_orders') }}) as pct
from {{ ref('fct_orders') }}
where is_orphan_order
having count(*) * 100.0 / (select count(*) from {{ ref('fct_orders') }}) > 1.0
