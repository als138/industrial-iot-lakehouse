from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_spark_session():
    """Create Spark session with Iceberg and Kafka configurations"""
    return SparkSession.builder \
        .appName("IoTDataProcessor") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.nessie", "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.nessie.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \
        .config("spark.sql.catalog.nessie.uri", "http://nessie:19120/api/v1") \
        .config("spark.sql.catalog.nessie.ref", "main") \
        .config("spark.sql.catalog.nessie.warehouse", "s3a://warehouse/") \
        .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
        .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
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

def detect_anomalies(df):
    """Implement anomaly detection logic"""
    # Calculate statistical bounds for anomaly detection
    temp_stats = df.select(
        mean("temperature_c").alias("temp_mean"),
        stddev("temperature_c").alias("temp_std")
    ).collect()[0]
    
    vib_stats = df.select(
        mean("vibration_mms").alias("vib_mean"),
        stddev("vibration_mms").alias("vib_std")
    ).collect()[0]
    
    # Define anomaly thresholds (3 sigma rule)
    temp_threshold_high = temp_stats["temp_mean"] + 3 * temp_stats["temp_std"]
    temp_threshold_low = temp_stats["temp_mean"] - 3 * temp_stats["temp_std"]
    vib_threshold_high = vib_stats["vib_mean"] + 3 * vib_stats["vib_std"]
    
    # Add anomaly flags
    return df.withColumn("temp_anomaly", 
                        (col("temperature_c") > temp_threshold_high) | 
                        (col("temperature_c") < temp_threshold_low)) \
             .withColumn("vibration_anomaly", 
                        col("vibration_mms") > vib_threshold_high)

def process_stream():
    """Main streaming processing function"""
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")
    
    # Read from Kafka
    kafka_df = spark \
        .readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", "kafka:9092") \
        .option("subscribe", "iot-sensor-data") \
        .option("startingOffsets", "earliest") \
        .load()
    
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
        .withColumn("is_fault", col("fault_label") > 0)
    
    # Aggregations for time windows
    windowed_df = transformed_df \
        .withWatermark("event_time", "10 minutes") \
        .groupBy(
            window(col("event_time"), "5 minutes"),
            col("machine_id")
        ) \
        .agg(
            avg("temperature_c").alias("avg_temperature"),
            max("temperature_c").alias("max_temperature"),
            min("temperature_c").alias("min_temperature"),
            avg("vibration_mms").alias("avg_vibration"),
            max("vibration_mms").alias("max_vibration"),
            avg("pressure_bar").alias("avg_pressure"),
            sum(col("is_fault").cast("int")).alias("fault_count"),
            count("*").alias("reading_count")
        )
    
    # Write to Iceberg table
    def write_to_iceberg(df, epoch_id):
        try:
            # Create database if not exists
            spark.sql("CREATE DATABASE IF NOT EXISTS nessie.iot_data")
            
            # Write raw data
            df.write \
                .format("iceberg") \
                .mode("append") \
                .option("write.format.default", "parquet") \
                .saveAsTable("nessie.iot_data.sensor_readings")
            
            logger.info(f"Successfully wrote batch {epoch_id} to Iceberg")
        except Exception as e:
            logger.error(f"Error writing batch {epoch_id}: {str(e)}")
    
    def write_aggregated_to_iceberg(df, epoch_id):
        try:
            spark.sql("CREATE DATABASE IF NOT EXISTS nessie.iot_data")
            
            df.write \
                .format("iceberg") \
                .mode("append") \
                .option("write.format.default", "parquet") \
                .saveAsTable("nessie.iot_data.sensor_aggregates")
            
            logger.info(f"Successfully wrote aggregated batch {epoch_id} to Iceberg")
        except Exception as e:
            logger.error(f"Error writing aggregated batch {epoch_id}: {str(e)}")
    
    # Start streaming queries
    raw_query = transformed_df.writeStream \
        .foreachBatch(write_to_iceberg) \
        .outputMode("append") \
        .trigger(processingTime='30 seconds') \
        .option("checkpointLocation", "/tmp/checkpoint/raw") \
        .start()
    
    aggregated_query = windowed_df.writeStream \
        .foreachBatch(write_aggregated_to_iceberg) \
        .outputMode("append") \
        .trigger(processingTime='60 seconds') \
        .option("checkpointLocation", "/tmp/checkpoint/aggregated") \
        .start()
    
    # Wait for termination
    raw_query.awaitTermination()
    aggregated_query.awaitTermination()

if __name__ == "__main__":
    process_stream()