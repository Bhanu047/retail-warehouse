{{ config(materialized='view') }}

/*
  One row per customer.

  The source re-exports rows, so this is where the fan-out is stopped. If
  it were not, every join through customers would multiply order counts,
  and it would show up as revenue that is quietly too high rather than as
  an error.

  Keeping the newest row per id via qualify: readable, and DuckDB pushes it
  down properly. Ordering by signup_date then customer_id makes the choice
  deterministic instead of arbitrary.
*/

with source as (
    select * from {{ source('raw', 'raw_customers') }}
),

deduplicated as (
    select *
    from source
    qualify row_number() over (
        partition by customer_id
        order by signup_date desc, customer_id
    ) = 1
)

select
    customer_id,
    first_name,
    last_name,
    -- Empty string and null mean the same thing here, and letting both
    -- through means every downstream check has to test for both.
    nullif(trim(email), '')                          as email,
    upper(trim(country))                             as country_code,
    signup_date,
    nullif(trim(email), '') is not null              as has_email
from deduplicated
