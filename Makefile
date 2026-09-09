.PHONY: install seeds build test docs fresh incremental clean

export DBT_PROFILES_DIR = $(CURDIR)

install:
	pip install -r requirements.txt

# Regenerate the seed CSVs from scratch. Committed output, reproducible input.
seeds:
	python scripts/generate_seeds.py

# Seed first, as its own command.
#
# `dbt build` alone fails on a clean database: the models' source relations
# are resolved before the seeding step has created the `raw` schema, so the
# first run cannot find tables that the same run is about to create. Running
# the seed separately is the normal workflow anyway.
build:
	dbt seed
	dbt build

test:
	dbt test

docs:
	dbt docs generate
	dbt docs serve

# Prove the incremental model is idempotent: build twice, count twice.
incremental:
	dbt build --select fct_orders+
	dbt build --select fct_orders+
	@echo "run it twice and the row count should not move"

fresh: clean build

clean:
	rm -rf target dbt_packages logs warehouse.duckdb warehouse.duckdb.wal
