{#-
    Deterministic surrogate key: md5 of the given columns, null-safe and
    delimiter-separated so ('a', 'bc') and ('ab', 'c') hash differently.
    Kept in-project instead of adding the dbt_utils package for one macro.
-#}
{% macro generate_surrogate_key(columns) -%}
    md5(
        {%- for column in columns %}
        coalesce(cast({{ column }} as varchar), '_null_')
        {%- if not loop.last %} || '|' || {% endif -%}
        {%- endfor %}
    )
{%- endmacro %}
