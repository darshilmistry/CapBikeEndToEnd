{{ config(materialized='table', schema='bronze') }}

WITH typed_n_tagged AS (
    SELECT
        q.ride_id,
        q.rideable_type, 
        q.start_station_name, 
        q.start_station_id, 
        q.end_station_name, 
        q.end_station_id, 
        q.start_lat, 
        q.start_lng, 
        q.end_lat, 
        q.end_lng, 
        q.member_casual,
        q.started_at::TIMESTAMP AS started_at,
        q.ended_at::TIMESTAMP   AS ended_at,
        CASE 
            WHEN end_lat IS NULL THEN 'Unreturned rideable'
            WHEN 
              q.started_at::TIME > '20:00:00.000' AND 
              q.ended_at::TIMESTAMP - q.started_at::TIMESTAMP > INTERVAL '05:00:00.000'
            THEN 'Logical Descripancy'
            ELSE 'Quarantined Resolved'
        END AS dq_status
    FROM {{ ref('QUARANTINE') }} AS q  
), station_resolved AS (
    SELECT
        q.*,
        CASE
            WHEN start_station_id IS NULL THEN -1
            ELSE start_station_id
        END AS resolved_start_station_ID,
        CASE
            when start_station_name IS NULL THEN 'UnDocked Start'
            ELSE start_station_name
        END AS resolved_start_station_name,
        CASE
            WHEN end_station_id IS NULL THEN -1
            ELSE end_station_id
        END AS resolved_end_station_id,
        CASE 
            WHEN end_station_name IS NULL THEN 'UnDocked End'
            ELSE end_station_name
        END AS resolved_end_station_name
    FROM {{ ref('QUARANTINE') }} AS q
)

SELECT 
    t.ride_id,
    t.rideable_type,
    t.started_at,
    t.ended_at,
    r.resolved_start_station_id AS start_station_id,
    r.resolved_start_station_name AS start_station_name,
    t.start_lat,
    t.start_lng,
    r.resolved_end_station_id AS end_station_id,
    r.resolved_end_station_name AS end_station_name,
    t.end_lat,
    t.end_lng,
    t.member_casual,
    t.dq_status
FROM typed_n_tagged t
  JOIN station_resolved r ON t.ride_id = r.ride_id