"""Generate the seed CSVs.

Committed so the fixtures can be regenerated and reviewed rather than
appearing from nowhere. Deterministic under a seed, and it deliberately
plants the problems the models are built to handle: duplicated source
rows, a late-arriving customer, cancelled orders, and prices stored in
cents.
"""

from __future__ import annotations

import csv
import datetime as dt
import random
from pathlib import Path

SEED = 42
START = dt.date(2024, 1, 1)
DAYS = 120

CATEGORIES = ["Audio", "Wearables", "Home", "Accessories", "Lighting"]
COUNTRIES = ["US", "GB", "DE", "FR", "CA", "AU"]
STATUSES = ["completed", "completed", "completed", "shipped", "cancelled", "returned"]


def _write(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def build(out: Path = Path("seeds")) -> dict[str, int]:
    random.seed(SEED)

    customers = []
    for i in range(1, 301):
        signup = START + dt.timedelta(days=random.randint(-400, DAYS - 1))
        customers.append(
            {
                "customer_id": i,
                "first_name": f"First{i}",
                "last_name": f"Last{i}",
                # Some contact details are genuinely missing upstream.
                "email": f"user{i}@example.com" if random.random() > 0.04 else "",
                "country": random.choice(COUNTRIES),
                "signup_date": signup.isoformat(),
            }
        )
    # The source system re-exports a handful of rows. Staging has to collapse
    # these or every downstream join fans out.
    duplicated = random.sample(customers, 12)
    customers.extend(duplicated)

    products = []
    for i in range(1, 61):
        products.append(
            {
                "product_id": i,
                "sku": f"SKU-{i:04d}",
                "product_name": f"Product {i}",
                "category": random.choice(CATEGORIES),
                # Money in integer cents at the source: floats and currency
                # do not belong together.
                "unit_price_cents": random.choice([999, 1499, 2499, 3999, 5999, 12999]),
                "is_active": random.choice(["true", "true", "true", "false"]),
                "updated_at": (START + dt.timedelta(days=random.randint(0, 30))).isoformat(),
            }
        )

    orders, items = [], []
    order_id = item_id = 1
    for day in range(DAYS):
        ordered_on = START + dt.timedelta(days=day)
        # Weekends are quieter, which gives the daily mart something real to show.
        base = 18 if ordered_on.weekday() < 5 else 9
        for _ in range(random.randint(base - 5, base + 5)):
            customer = random.randint(1, 300)
            status = random.choice(STATUSES)
            orders.append(
                {
                    "order_id": order_id,
                    "customer_id": customer,
                    "ordered_at": dt.datetime.combine(
                        ordered_on, dt.time(random.randint(6, 22), random.randint(0, 59))
                    ).isoformat(),
                    "status": status,
                    "currency": "USD",
                }
            )
            for _ in range(random.randint(1, 4)):
                product = random.choice(products)
                items.append(
                    {
                        "order_item_id": item_id,
                        "order_id": order_id,
                        "product_id": product["product_id"],
                        "quantity": random.randint(1, 3),
                        "unit_price_cents": product["unit_price_cents"],
                        "discount_cents": random.choice([0, 0, 0, 200, 500]),
                    }
                )
                item_id += 1
            order_id += 1

    # One order from a customer the customer export has not caught up with.
    # A referential test that ignores this would be lying; the staging layer
    # is where it gets handled.
    orders.append(
        {
            "order_id": order_id,
            "customer_id": 9999,
            "ordered_at": dt.datetime.combine(
                START + dt.timedelta(days=DAYS - 1), dt.time(12, 0)
            ).isoformat(),
            "status": "completed",
            "currency": "USD",
        }
    )
    items.append(
        {
            "order_item_id": item_id,
            "order_id": order_id,
            "product_id": 1,
            "quantity": 1,
            "unit_price_cents": 999,
            "discount_cents": 0,
        }
    )

    _write(out / "raw_customers.csv", customers)
    _write(out / "raw_products.csv", products)
    _write(out / "raw_orders.csv", orders)
    _write(out / "raw_order_items.csv", items)

    return {
        "customers": len(customers),
        "products": len(products),
        "orders": len(orders),
        "order_items": len(items),
    }


if __name__ == "__main__":
    for name, count in build().items():
        print(f"{name:<14} {count:>6,} rows")
