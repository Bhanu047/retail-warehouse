{{ config(materialized='view') }}

/*
  One row per order header.

  `is_revenue` is defined once, here, because "which orders count as
  revenue" is the single question most likely to be answered inconsistently
  across a warehouse. Cancelled and returned orders exist and matter --
  they are kept, flagged, and filtered at the mart, not dropped at staging.
  Dropping them would make the cancellation rate unmeasurable.
*/

select
    order_id,
    customer_id,
    ordered_at,
    cast(ordered_at as date)                            as ordered_date,
    lower(trim(status))                                 as status,
    currency,
    lower(trim(status)) in ('completed', 'shipped')     as is_revenue,
    lower(trim(status)) = 'cancelled'                   as is_cancelled,
    lower(trim(status)) = 'returned'                    as is_returned
from {{ source('raw', 'raw_orders') }}
