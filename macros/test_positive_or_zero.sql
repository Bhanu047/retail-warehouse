{#
  A custom generic test.

  `dbt_utils` has one of these, but a single small test is not worth a
  package dependency -- `dbt deps` then needs network access, which makes
  CI slower and able to fail for reasons unrelated to the code.
#}

{% test positive_or_zero(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
