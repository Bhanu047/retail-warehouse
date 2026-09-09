{% snapshot products_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['unit_price_cents', 'is_active', 'category'],
        invalidate_hard_deletes=True
    )
}}

/*
  Slowly changing dimension, type 2.

  The source overwrites a product row in place, so a price change destroys
  the old price. That makes "what did this cost when the order was placed"
  unanswerable, which is the question every revenue restatement turns on.

  `check` strategy rather than `timestamp` because the source's updated_at
  is not reliably touched on every write -- trusting it would silently miss
  changes. Checking the columns that matter costs a comparison and cannot
  be fooled by a missed timestamp update.

  `invalidate_hard_deletes` so a delisted product is closed off rather than
  frozen open forever.
*/

select
    product_id,
    sku,
    product_name,
    category,
    unit_price_cents,
    is_active,
    updated_at
from {{ ref('stg_products') }}

{% endsnapshot %}
