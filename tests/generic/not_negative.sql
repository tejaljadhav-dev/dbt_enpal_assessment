{#- Fails on any row where the column is below zero (nulls are left to not_null). -#}
{% test not_negative(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
