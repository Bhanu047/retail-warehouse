# Retail warehouse

[![CI](https://github.com/Bhanu047/retail-warehouse/actions/workflows/ci.yml/badge.svg)](https://github.com/Bhanu047/retail-warehouse/actions/workflows/ci.yml)

A dbt project on DuckDB: raw exports through staging and marts, with tests, a type-2 snapshot, and an incremental fact table.

```
seeds (raw)  →  staging (typed, deduped)  →  intermediate (ephemeral)  →  marts
                        │
                        └─→  snapshot (SCD2 on products)
```

Runs on a clone with no setup — DuckDB is a file, so there's no warehouse to provision and no credentials to hand out. The SQL is ordinary enough to move to Snowflake or BigQuery by changing the profile.

Most of this README is about the decisions rather than the models, same as my other repos. There are only about a dozen models and they read quickly.

## Running it

```bash
pip install -r requirements.txt
make build      # seed, run, test: 4 seeds + 12 models + 57 tests
make docs       # lineage graph in the browser
```

## Why `dbt seed` is a separate step

`dbt build` on its own fails on a clean database, and the error is confusing: models can't find tables that the same command is about to create.

The reason is that model source relations get resolved before the seeding step has created the `raw` schema. Seeding separately fixes it, and it's the normal workflow anyway — seeds change rarely and rebuilding them on every run is wasted work.

I mention it because I hit it, spent a few minutes assuming the schema config was wrong, and it wasn't.

## Why money never becomes a float until the last step

The source stores amounts as integer cents, which is correct. Floating point can't represent `0.10` exactly, and the error compounds across a `sum` — on enough rows, a total is visibly wrong and nobody can say why.

So cents stay integers through staging and intermediate, and convert only at the mart boundary where a human reads them. The conversion is a macro rather than inline SQL so the rounding rule is defined once. Two models rounding differently is how a total stops matching the sum of its parts.

The line-total macro also floors at zero. A discount larger than the line value would otherwise produce negative revenue, and a handful of those quietly drag a daily total down.

## Why cancelled orders are kept, not filtered

It's tempting to drop them in staging — the marts only want revenue. But then the cancellation rate becomes unmeasurable, and that's a number someone asks for eventually.

So cancelled and returned orders are kept and flagged. `is_revenue` is defined once, in `stg_orders`, because "which orders count as revenue" is the question most likely to get answered inconsistently across a warehouse.

`fct_daily_revenue` builds on `fct_orders` rather than going back to staging, so it inherits that definition instead of restating it. Two models each deciding what counts as revenue is how a dashboard and a finance report end up disagreeing by four percent, with no way to tell which is right.

There's a test asserting the two reconcile.

## Why the incremental model has a lookback

`fct_orders` is incremental with `unique_key` and `delete+insert`. The unique key is what makes a re-run idempotent — without it, an incremental model appends, and re-running yesterday duplicates yesterday.

The part people leave out is the lookback. Filtering on `ordered_date > max(ordered_date)` misses any order that arrives late for a day already loaded, and nothing ever tells you. Re-processing a three-day trailing window costs almost nothing, and it's only safe because the load replaces whole orders rather than appending.

CI builds twice for this reason. The first run of an incremental model takes the full-refresh path and never touches the incremental branch, so a bug there survives any single-run test.

## Why the snapshot uses `check` rather than `timestamp`

The source overwrites product rows in place, so a price change destroys the old price. That makes "what did this cost when the order was placed" unanswerable — which is the question every revenue restatement turns on.

`timestamp` strategy would be cheaper, but it trusts `updated_at`, and this source doesn't reliably touch that column on every write. A missed timestamp means a silently missed change. Comparing the columns that actually matter costs more and can't be fooled.

`invalidate_hard_deletes` is on so a delisted product gets closed off rather than frozen open forever.

## Why some tests are thresholds rather than assertions

Orders can reference a customer the export hasn't caught up with. There's one in the seed data deliberately.

A `relationships` test between orders and customers would fail every run for a condition that is entirely normal. And a test that always fails is a test everyone learns to ignore, which is worse than not having it — it trains people to skim past red.

So `fct_orders` labels those rows (`is_orphan_order`, `country_code = 'UNKNOWN'`) rather than dropping them, and a singular test fails only if they exceed 1% of orders. That threshold is the actual thing worth alerting on: a few is normal, a lot means the customer feed has broken.

The same reasoning is why `stg_customers` deduplicates rather than testing for uniqueness at the source. The source genuinely re-exports rows; asserting it doesn't would be asserting something false.

## Why staging is views and marts are tables

Staging is read once by the layer above and is cheap to recompute, so a view costs nothing and always reflects the source.

Intermediate models are ephemeral — they're joined by two marts and never queried directly, so materialising them would leave tables nobody reads. dbt inlines them as CTEs.

Marts are tables. They're read far more often than they're written, and they're small.

## The tests

57 of them, and the two worth reading are the singular ones:

- **`assert_order_total_matches_lines`** catches a join fanning out. If a duplicate crept back into `stg_customers`, or `int_order_totals` grouped on the wrong key, the totals and the lines would diverge — and no column-level test would notice, because both numbers would still be non-null and positive.
- **`assert_daily_revenue_reconciles`** checks the aggregate against its source. An aggregate that quietly disagrees with the table it's built from is the most expensive kind of warehouse bug, because two people quote two numbers and neither is obviously wrong.

The generic tests are the ordinary ones — uniqueness, not-null, accepted values, referential integrity where it genuinely holds — plus two custom ones (`positive_or_zero`, `not_in_the_future`) written locally rather than pulled from `dbt_utils`. A single small test isn't worth a package dependency; `dbt deps` then needs network access, and CI gains a way to fail for reasons unrelated to the code.

## Layout

```
seeds/                     Raw CSVs, generated by scripts/generate_seeds.py
models/staging/            One model per source table: typed, renamed, deduped
models/intermediate/       Ephemeral joins used by more than one mart
models/marts/              dim_customers, dim_products, fct_orders, fct_daily_revenue
snapshots/                 SCD2 on products
macros/                    Money handling, schema naming, two custom tests
tests/                     Three singular tests
scripts/generate_seeds.py  Deterministic fixture generation
```

## What's missing

On purpose:

- **No `dbt_utils`.** Two small custom tests instead, so CI needs no network.
- **No exposures or metrics.** Both are worth having when something downstream actually consumes the marts. Declaring them with no consumer is documentation of a thing that doesn't exist.
- **No source freshness checks.** Seeds have no freshness to check. Against a real source this is the first thing I'd add.
- **DuckDB rather than a real warehouse.** The point is that it runs on a clone. Nothing here depends on DuckDB except the profile.
