from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging

def create_iceberg_spark_session():
    """Create Spark session with Iceberg and Nessie configurations"""
    return SparkSession.builder \
        .appName("IoTLakehouseProcessor") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.nessie", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.nessie.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \
        .config("spark.sql.catalog.nessie.uri", "http://nessie:19120/api/v2") \
        .config("spark.sql.catalog.nessie.ref", "main") \
        .config("spark.sql.catalog.nessie.warehouse", "s3a://warehouse/folder/") \
        .config("spark.sql.catalog.nessie.s3.endpoint", "http://minio:9000") \
        .config("spark.sql.catalog.nessie.s3.access-key-id", "minioadmin") \
        .config("spark.sql.catalog.nessie.s3.secret-access-key", "minioadmin") \
        .config("spark.sql.catalog.nessie.s3.path-style-access", "true") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .getOrCreate()

def define_schema():
    """Define schema for IoT data"""
    return StructType([
        StructField("timestamp", StringType(), True),
        StructField("machine_id", StringType(), True),
        StructField("vibration_mms", DoubleType(), True),
        StructField("temperature_c", DoubleType(), True),
        StructField("pressure_bar", DoubleType(), True),
        StructField("rms_vibration", DoubleType(), True),
        StructField("mean_temp", DoubleType(), True),
        StructField("fault_label", IntegerType(), True)
    ])

def initialize_iceberg_tables(spark):
    """Initialize Iceberg tables in Nessie catalog"""
    print("🏗️ Initializing Iceberg tables...")
    
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
            is_fault boolean,
            temp_status string,
            processing_time timestamp,
            time_window timestamp
        ) USING iceberg
        PARTITIONED BY (date, machine_id, time_window)
        TBLPROPERTIES (
            'write.format.default' = 'parquet',
            'write.parquet.compression-codec' = 'snappy'
        )
    """)
    
    # Create aggregated metrics table
    spark.sql("""
        CREATE TABLE IF NOT EXISTS nessie.iot_data.sensor_metrics (
            window_start timestamp,
            window_end timestamp,
            machine_id string,
            avg_temperature double,
            max_temperature double,
            min_temperature double,
            avg_vibration double,
            max_vibration double,
            avg_pressure double,
            fault_count bigint,
            total_readings bigint,
            fault_percentage double,
            processing_time timestamp
        ) USING iceberg
        PARTITIONED BY (machine_id, date(window_start))
        TBLPROPERTIES (
            'write.format.default' = 'parquet',
            'write.parquet.compression-codec' = 'snappy'
        )
    """)
    
    print("✅ Iceberg tables initialized successfully!")

def process_stream_to_iceberg():
    """Main streaming processing function with Iceberg storage"""
    spark = create_iceberg_spark_session()
    spark.sparkContext.setLogLevel("WARN")
    
    print("🚀 Starting Spark Streaming with Iceberg storage...")
    
    # Initialize tables
    initialize_iceberg_tables(spark)
    
    # Connect to Kafka
    kafka_bootstrap_servers = "kafka:29092"
    print(f"📡 Connecting to Kafka at: {kafka_bootstrap_servers}")
    
    kafka_df = spark \
        .readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", kafka_bootstrap_servers) \
        .option("subscribe", "iot-sensor-data") \
        .option("startingOffsets", "latest") \
        .option("kafka.security.protocol", "PLAINTEXT") \
        .option("failOnDataLoss", "false") \
        .load()
    
    print("✅ Connected to Kafka successfully!")
    
    # Parse JSON data
    schema = define_schema()
    parsed_df = kafka_df.select(
        from_json(col("value").cast("string"), schema).alias("data")
    ).select("data.*")
    
    # Data transformations
    transformed_df = parsed_df \
        .withColumn("event_time", to_timestamp(col("timestamp"))) \
        .withColumn("date", to_date(col("event_time"))) \
        .withColumn("hour", hour(col("event_time"))) \
        .withColumn("temp_fahrenheit", col("temperature_c") * 9/5 + 32) \
        .withColumn("pressure_psi", col("pressure_bar") * 14.5038) \
        .withColumn("is_fault", col("fault_label") > 0) \
        .withColumn("temp_status", 
                   when(col("temperature_c") > 80, "HIGH")
                   .when(col("temperature_c") < 20, "LOW")
                   .otherwise("NORMAL")) \
        .withColumn("processing_time", current_timestamp()) \
        .withColumn(
            "time_window",
            date_trunc(
                "minute",
                from_unixtime(
                    (floor(unix_timestamp(col("event_time")) / (15 * 60)) * (15 * 60))
                ).cast("timestamp")
            )
        )
    
    # Function to write to Iceberg
    def write_batch_to_iceberg(batch_df, batch_id):
        print(f"📊 Processing batch {batch_id} with {batch_df.count()} records")
        
        try:
            # Write to raw sensor readings table
            batch_df.write \
                .format("iceberg") \
                .mode("append") \
                .saveAsTable("nessie.iot_data.sensor_readings")
            
            print(f"✅ Batch {batch_id} written to sensor_readings table")
            
            # Create aggregated metrics (5-minute windows)
            metrics_df = batch_df \
                .groupBy(
                    window(col("event_time"), "15 minutes"),
                    col("machine_id")
                ) \
                .agg(
                    avg("temperature_c").alias("avg_temperature"),
                    max("temperature_c").alias("max_temperature"),
                    min("temperature_c").alias("min_temperature"),
                    avg("vibration_mms").alias("avg_vibration"),
                    max("vibration_mms").alias("max_vibration"),
                    avg("pressure_bar").alias("avg_pressure"),
                    sum(col("is_fault").cast("long")).alias("fault_count"),
                    count("*").alias("total_readings")
                ) \
                .withColumn("fault_percentage", 
                           (col("fault_count") * 100.0 / col("total_readings"))) \
                .withColumn("window_start", col("window.start")) \
                .withColumn("window_end", col("window.end")) \
                .withColumn("processing_time", current_timestamp()) \
                .drop("window")
            
            # Write aggregated metrics
            if metrics_df.count() > 0:
                metrics_df.write \
                    .format("iceberg") \
                    .mode("append") \
                    .saveAsTable("nessie.iot_data.sensor_metrics")
                
                print(f"✅ Batch {batch_id} metrics written to sensor_metrics table")
            
        except Exception as e:
            print(f"❌ Error writing batch {batch_id}: {str(e)}")
    
    # Start streaming query to Iceberg
    iceberg_query = transformed_df.writeStream \
        .foreachBatch(write_batch_to_iceberg) \
        .outputMode("append") \
        .trigger(processingTime='30 seconds') \
        .option("checkpointLocation", "/tmp/checkpoint/iceberg") \
        .start()
    
    # Also output to console for monitoring
    console_query = transformed_df.writeStream \
        .outputMode("append") \
        .format("console") \
        .option("truncate", False) \
        .trigger(processingTime='10 seconds') \
        .start()
    
    print("🎯 Spark Streaming with Iceberg started successfully!")
    print("💾 Data is being written to MinIO via Iceberg tables")
    print("📈 Check Nessie catalog and MinIO for stored data")
    print("=" * 80)
    
    # Wait for termination
    iceberg_query.awaitTermination()

if __name__ == "__main__":
    try:
        process_stream_to_iceberg()
    except Exception as e:
        print(f"❌ Error in Iceberg streaming processor: {e}")
        import traceback
        traceback.print_exc()