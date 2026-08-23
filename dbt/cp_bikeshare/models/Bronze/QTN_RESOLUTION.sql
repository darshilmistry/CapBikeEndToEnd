
WITH typed AS (
    SELECT
        q.*,
        q.started_at::TIMESTAMP AS ts_start,
        q.ended_at::TIMESTAMP   AS ts_end
    FROM {{ source('bronze', 'QUARANTINE') }} AS q
)

SELECT
    t.*,
    CASE
        -- overnight, long-running: likely undocked, needs system-side data
        WHEN t.ts_start::DATE <> t.ts_end::DATE
             AND (t.ts_end - t.ts_start) > INTERVAL '4 hours'
            THEN 'unresolvable_needs_internal_data'

        -- coordinates too coarse to impute a station (~1km box in DC)
        WHEN (t.start_station_id IS NULL OR t.end_station_id IS NULL)
             AND (
                  SCALE(t.start_lat::NUMERIC) <= 2
               OR SCALE(t.start_lng::NUMERIC) <= 2
               OR SCALE(t.end_lat::NUMERIC)   <= 2
               OR SCALE(t.end_lng::NUMERIC)   <= 2
             )
            THEN 'unresolvable_coord_precision'

        -- no station id but usable coordinates
        WHEN t.start_station_id IS NULL OR t.end_station_id IS NULL
            THEN 'plausible_dockless'

        ELSE 'repairable'
    END AS resolution
FROM typed AS t

LIMIT 5;