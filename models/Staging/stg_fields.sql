with source as (

    select * from {{ source('pipedrive', 'fields') }}

),

unnested as (

    -- field_value_options is a JSON array of {"id", "label"} objects;
    -- expand it to one row per option. The left join keeps fields without
    -- options (add_time, user_id) as a single row with null option columns.
    select
        source.id               as field_id,
        source.field_key        as field_key,
        source.name             as field_name,
        -- text, to match deal_changes.new_value
        option ->> 'id'         as option_id,
        option ->> 'label'      as option_label
    from source
    left join lateral jsonb_array_elements(source.field_value_options) as option
        on true

),

final as (

    select
        -- option ids restart at 1 for every field, so the key includes field_key
        {{ generate_surrogate_key(['field_key', 'option_id']) }} as field_option_id,
        field_id                as field_id,
        field_key               as field_key,
        field_name              as field_name,
        option_id               as option_id,
        option_label            as option_label
    from unnested

)

select * from final
