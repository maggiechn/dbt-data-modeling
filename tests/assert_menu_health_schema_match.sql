WITH json_keys AS (
    SELECT DISTINCT
        k.value::STRING AS key_name
    FROM {{ source('tasty_bytes', 'MENU') }},
    LATERAL FLATTEN(input => OBJECT_KEYS(menu_item_health_metrics_obj:menu_item_health_metrics[0])) k
),

table_columns AS (
    SELECT 
        column_name
    FROM DBT_TUTORIAL_DB.INFORMATION_SCHEMA.COLUMNS
    WHERE table_name = 'DIM_MENU_HEALTH' -- Matches your actual model name
      AND table_schema = 'DBT_DATA_MODELING'
)

SELECT
    j.key_name,
    c.column_name
FROM json_keys j
FULL OUTER JOIN table_columns c 
    ON UPPER(j.key_name) = UPPER(c.column_name)
-- THE IMPORTANT PART: A test only "fails" if it returns data.
-- We want it to return rows only if there is a mismatch.
WHERE j.key_name IS NULL 
   OR c.column_name IS NULL