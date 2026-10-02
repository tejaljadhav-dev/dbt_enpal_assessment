{#-
    Cast text to integer, returning null instead of failing when the value is
    not a plain whole number (e.g. 'abc', '1.5', ''). Needed because
    deal_changes.new_value holds mixed content, so one bad row would otherwise
    abort the whole run. Bad values become null and are caught by the not_null /
    relationships tests on the casted column, which fails one test with a clear
    cause instead of the whole build.
    The 1-9 digit limit keeps the value inside the integer range.
    Postgres has no try_cast, hence the regex guard; other adapters can add
    their own implementation under the dispatch.
-#}
{% macro safe_cast_integer(column) -%}
    {{ return(adapter.dispatch('safe_cast_integer')(column)) }}
{%- endmacro %}

{% macro default__safe_cast_integer(column) -%}
    try_cast({{ column }} as integer)
{%- endmacro %}

{% macro postgres__safe_cast_integer(column) -%}
    case
        when {{ column }} ~ '^[0-9]{1,9}$' then cast({{ column }} as integer)
    end
{%- endmacro %}
