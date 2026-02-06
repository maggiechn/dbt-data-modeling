{{
    config(
        materialized='incremental',
        unique_key='menu_item_id',
        schema='DBT_DATA_MODELING'
    )
}}

WITH source_data AS (
    SELECT 
        menu_item_health_metrics_obj,
        -- Create a unique fingerprint of the entire JSON object
        HASH(menu_item_health_metrics_obj) as row_hash
    FROM {{ source('tasty_bytes', 'MENU') }}
),

flattened AS (
    SELECT
        menu_item_health_metrics_obj:menu_item_id::INT AS menu_item_id,
        f.value AS metrics_record,
        row_hash
    FROM source_data,
    LATERAL FLATTEN(input => menu_item_health_metrics_obj:menu_item_health_metrics) f
)

SELECT
    menu_item_id,
    -- Extracting indicators with fallback for missing keys
    COALESCE(metrics_record:is_dairy_free_flag::VARCHAR, 'U') AS is_dairy_free_flag,
    COALESCE(metrics_record:is_gluten_free_flag::VARCHAR, 'U') AS is_gluten_free_flag,
    COALESCE(metrics_record:is_healthy_flag::VARCHAR, 'U') AS is_healthy_flag,
    COALESCE(metrics_record:is_nut_free_flag::VARCHAR, 'U') AS is_nut_free_flag,
    
    -- Converting the ingredients array to a string
    ARRAY_TO_STRING(metrics_record:ingredients, ', ') AS ingredients_list,
    
    -- Keep the hash in the final table to compare against in the next run
    row_hash

FROM flattened

{% if is_incremental() %}
  -- This filter only runs during 'dbt run'. 
  -- It skips any IDs that haven't changed their JSON content.
  WHERE (menu_item_id, row_hash) NOT IN (SELECT menu_item_id, row_hash FROM {{ this }})
{% endif %}