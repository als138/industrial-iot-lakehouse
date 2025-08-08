-- Query 1: Temperature trends over time
-- This query calculates the average, maximum, minimum, and count of temperature readings for each machine over the last 7 days.
-- It groups the results by date and machine ID and orders them by date in descending order.
SELECT
  machine_id,
  event_time,
  temperature_c
FROM warehouse."iot_data"."sensor_readings" AT BRANCH "main"
WHERE event_time IS NOT NULL
  AND temperature_c IS NOT NULL
ORDER BY event_time

-- Query 2: Fault analysis by machine
-- This query calculates the total number of readings, the number of faulty readings, and the percentage of faulty readings for each machine.
-- It groups the results by machine ID and orders them by the percentage of faulty readings in descending order.    
SELECT 
    machine_id,
    COUNT(*) as total_readings,
    SUM(CASE WHEN is_fault THEN 1 ELSE 0 END) as fault_count,
    ROUND(
        (SUM(CASE WHEN is_fault THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2
    ) as fault_percentage
FROM warehouse."iot_data"."sensor_readings" AT BRANCH "main"
GROUP BY machine_id
ORDER BY fault_percentage DESC;

-- Query 3: Hourly temperature and vibration patterns
-- This query calculates the average temperature, vibration, and pressure readings for each hour.
-- It groups the results by hour and orders them by hour in ascending order.
SELECT 
    "hour",
    AVG(temperature_c) as avg_temperature,
    AVG(vibration_mms) as avg_vibration,
    AVG(pressure_bar) as avg_pressure,
    COUNT(*) as reading_count,
    SUM(CASE WHEN is_fault THEN 1 ELSE 0 END) as fault_count
FROM warehouse."iot_data"."sensor_readings" AT BRANCH "main"
GROUP BY "hour"
ORDER BY "hour";

-- Query 4: Recent high-risk readings
-- This query selects the most recent 50 readings that are either high-risk or have a fault.
-- It orders the results by event time in descending order and limits the results to 50 rows.
SELECT 
    "event_time",
    "machine_id",
    "temperature_c",
    "vibration_mms",
    "pressure_bar",
    "temp_status",
    "is_fault"
FROM warehouse."iot_data"."sensor_readings" AT BRANCH "main"
WHERE 
    "temp_status" = 'HIGH' 
    OR "vibration_mms" > 8.0 
    OR "pressure_bar" > 2.5
ORDER BY "event_time" DESC
LIMIT 50;

-- Query 5: Aggregated metrics view
-- This query calculates the average temperature, maximum vibration, fault percentage, and total readings for each machine.
-- It groups the results by machine ID and orders them by window start in descending order and fault percentage in descending order.
SELECT 
    machine_id,
    window_start,
    window_end,
    avg_temperature,
    max_vibration,
    fault_percentage,
    total_readings
FROM warehouse."iot_data"."sensor_metrics" AT BRANCH "main"
WHERE fault_percentage > 10
ORDER BY window_start DESC, fault_percentage DESC;