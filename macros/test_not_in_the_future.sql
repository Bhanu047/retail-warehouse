{#
  Timestamps ahead of now mean a clock skew somewhere upstream, or a
  timezone applied twice. Both produce data that looks fine until someone
  filters on a date range and silently misses rows.
#}

{% test not_in_the_future(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} > current_timestamp

{% endtest %}
