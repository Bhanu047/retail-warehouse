{#
  Use the schema configured on the model rather than dbt's default of
  prefixing it with the target schema.

  dbt's built-in behaviour produces `main_staging`, `main_marts` and so on,
  which reads badly and couples every schema name to whatever the developer
  happened to call their target. This gives plain `staging` and `marts`.
#}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
