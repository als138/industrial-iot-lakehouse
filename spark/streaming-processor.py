from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

def create_spark_session():
    """Create Spark session with Kafka configurations"""
    return SparkSession.builder \
        .appName("IoTDataProcessor") \
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

def process_stream():
    """Main streaming processing function"""
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")
    
    print("🚀 Starting Spark Streaming processor...")
    
    # Use simple container name for Kafka
    kafka_bootstrap_servers = "kafka:29092"
    
    print(f"📡 Connecting to Kafka at: {kafka_bootstrap_servers}")
    
    # Read from Kafka
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
    print("🔍 Waiting for messages on topic: iot-sensor-data")
    
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
                   .otherwise("NORMAL"))
    
    # Console output for monitoring
    query = transformed_df.writeStream \
        .outputMode("append") \
        .format("console") \
        .option("truncate", False) \
        .trigger(processingTime='5 seconds') \
        .start()
    
    print("🎯 Spark Streaming started successfully!")
    print("📊 Processed data will appear below:")
    print("=" * 80)
    
    # Wait for termination
    query.awaitTermination()

if __name__ == "__main__":
    try:
        process_stream()
    except Exception as e:
        print(f"❌ Error in streaming processor: {e}")
        import traceback
        traceback.print_exc()
