{#
  Money handling, in one place.

  The source stores amounts as integer cents, which is the correct way to
  store money -- floating point cannot represent 0.10 exactly, and the
  error compounds across a sum. Everything stays in cents through staging
  and intermediate, and only converts at the mart boundary where a human
  reads it.

  Doing it as a macro rather than inline means the rounding rule is
  defined once. Two models rounding differently is how a total stops
  matching the sum of its parts.
#}

{% macro cents_to_dollars(column, precision=2) -%}
    round({{ column }} / 100.0, {{ precision }})
{%- endmacro %}


{#
  Line total in cents: quantity times price, less discount, floored at zero.

  The floor matters. A discount larger than the line value would otherwise
  produce negative revenue, and a handful of those quietly drag a daily
  total down in a way nobody notices until month end.
#}
{% macro line_total_cents(quantity, unit_price, discount) -%}
    greatest(({{ quantity }} * {{ unit_price }}) - coalesce({{ discount }}, 0), 0)
{%- endmacro %}
