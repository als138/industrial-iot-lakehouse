from pyspark.sql import SparkSession

def initialize_tables():
    spark = create_spark_session()
    
    # Create database
    spark.sql("CREATE DATABASE IF NOT EXISTS nessie.iot_data")
    
    # Create raw sensor readings table
    spark.sql("""
        CREATE TABLE IF NOT EXISTS nessie.iot_data.sensor_readings (
            timestamp string,
            machine_id string,
            vibration_mms double,
            temperature_c double,
            pressure_bar double,
            rms_vibration double,
            mean_temp double,
            fault_label int,
            event_time timestamp,
            date date,
            hour int,
            temp_fahrenheit double,
            pressure_psi double,
            is_fault boolean
        ) USING iceberg
        PARTITIONED BY (date, machine_id)
    """)
    
    # Create aggregated table
    spark.sql("""
        CREATE TABLE IF NOT EXISTS nessie.iot_data.sensor_aggregates (
            window struct<start:timestamp,end:timestamp>,
            machine_id string,
            avg_temperature double,
            max_temperature double,
            min_temperature double,
            avg_vibration double,
            max_vibration double,
            avg_pressure double,
            fault_count int,
            reading_count int
        ) USING iceberg
        PARTITIONED BY (machine_id)
    """)

if __name__ == "__main__":
    initialize_tables()