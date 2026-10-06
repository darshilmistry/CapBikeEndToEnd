{{ config(
    materialized='incremental',
    unique_key='ride_id',
    schema='gold'
) }}

WITH src AS (
    SELECT
        s.ride_id,
        s.rideable_type,
        s.start_time,
        s.end_time,
        s.start_stn_id,
        s.end_stn_id,
        s.rider_type,
        s.dq_status,
        md5(ROW(
            s.rideable_type, s.start_time, s.end_time,
            s.start_stn_id, s.end_stn_id, s.rider_type, s.dq_status
        )::text) AS row_hash
    FROM {{ ref('trips') }} s
)

SELECT
    src.*,
    '{{ run_started_at }}'::timestamptz AS modified_at
FROM src

{% if is_incremental() %}
LEFT JOIN {{ this }} g ON g.ride_id = src.ride_id
WHERE g.ride_id IS NULL                                   
  {% if var('update_existing', false) %}
   OR g.row_hash IS DISTINCT FROM src.row_hash            
  {% endif %}
{% endif %}