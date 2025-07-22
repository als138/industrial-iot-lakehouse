#!/usr/bin/env python3
"""
Industrial IoT Data Processing with Spark Structured Streaming
This application processes real-time industrial sensor data from Kafka,
performs data cleaning, transformations, and stores results in Iceberg tables.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging
from datetime import datetime

# Configure logging for monitoring streaming application
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class IndustrialIoTProcessor:
    """
    Spark Structured Streaming processor for industrial IoT data.
    Handles real-time data processing, anomaly detection, and storage.
    """
    
    def __init__(self):
        """Initialize Spark session with required configurations for streaming and Iceberg."""
        self.spark = None
        self._setup_spark_session()
    
    def _setup_spark_session(self):
        """
        Configure Spark session with all necessary dependencies for Kafka, Iceberg, and MinIO.
        This is a critical step that enables integration between all components.
        """
        try:
            self.spark = SparkSession.builder \
                .appName("IndustrialIoTProcessor") \
                .config("spark.sql.adaptive.enabled", "true") \
                .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
                .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
                .config("spark.sql.streaming.checkpointLocation", "/tmp/spark-checkpoints") \
                .config("spark.sql.catalog.nessie", "org.apache.iceberg.spark.SparkCatalog") \
                .config("spark.sql.catalog.nessie.type", "rest") \
                .config("spark.sql.catalog.nessie.uri", "http://nessie:19120/api/v1") \
                .config("spark.sql.catalog.nessie.warehouse", "s3a://lakehouse/warehouse/") \
                .config("spark.sql.catalog.nessie.s3.endpoint", "http://minio:9000") \
                .config("spark.sql.catalog.nessie.s3.access-key-id", "minioadmin") \
                .config("spark.sql.catalog.nessie.s3.secret-access-key", "minioadmin123") \
                .config("spark.sql.catalog.nessie.s3.path-style-access", "true") \
                .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
                .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
                .config("spark.hadoop.fs.s3a.secret.key", "minioadmin123") \
                .config("spark.hadoop.fs.s3a.path.style.access", "true") \
                .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
                .getOrCreate()
            
            # Set log level to reduce verbose output while maintaining important information
            self.spark.sparkContext.setLogLevel("WARN")
            logger.info("Spark session initialized successfully with Iceberg and S3 support")
            
        except Exception as e:
            logger.error(f"Failed to initialize Spark session: {e}")
            raise
    
    def _define_schema(self):
        """
        Define the expected schema for incoming IoT data.
        Having a predefined schema improves performance and enables proper data validation.
        """
        return StructType([
            StructField("sensor_id", StringType(), False),
            StructField("timestamp", TimestampType(), False), 
            StructField("temperature", DoubleType(), False),
            StructField("vibration", DoubleType(), False),
            StructField("pressure", DoubleType(), False),
            StructField("machine_status", StringType(), True),
            StructField("location", StringType(), True),
            StructField("equipment_type", StringType(), True),
            StructField("data_quality", StringType(), True)
        ])
    
    def _read_kafka_stream(self, kafka_servers="kafka:29092", topic="industrial-iot-data"):
        """
        Create a streaming DataFrame from Kafka topic.
        This establishes the connection between Kafka and Spark for real-time processing.
        
        Args:
            kafka_servers: Kafka bootstrap servers
            topic: Kafka topic to consume from
            
        Returns:
            Streaming DataFrame with raw Kafka data
        """
        try:
            # Read from Kafka with proper configuration for fault tolerance
            kafka_stream = self.spark \
                .readStream \
                .format("kafka") \
                .option("kafka.bootstrap.servers", kafka_servers) \
                .option("subscribe", topic) \
                .option("startingOffsets", "latest") \
                .option("failOnDataLoss", "false") \
                .option("kafka.session.timeout.ms", "30000") \
                .option("kafka.request.timeout.ms", "40000") \
                .load()
            
            logger.info(f"Successfully created Kafka stream for topic: {topic}")
            return kafka_stream
            
        except Exception as e:
            logger.error(f"Failed to create Kafka stream: {e}")
            raise
    
    def _parse_json_data(self, kafka_df):
        """
        Parse JSON data from Kafka messages and apply schema validation.
        This step transforms the raw Kafka messages into structured data we can analyze.
        
        Args:
            kafka_df: Raw Kafka DataFrame
            
        Returns:
            Parsed DataFrame with proper schema
        """
        # Parse the JSON value from Kafka message
        parsed_df = kafka_df.select(
            col("key").cast("string").alias("message_key"),
            col("timestamp").alias("kafka_timestamp"),
            from_json(col("value").cast("string"), self._define_schema()).alias("data")
        ).select(
            col("message_key"),
            col("kafka_timestamp"),
            col("data.*")
        )
        
        # Convert timestamp string to proper timestamp type
        # This handles the ISO format timestamps from our producer
        parsed_df = parsed_df.withColumn(
            "timestamp", 
            to_timestamp(col("timestamp"), "yyyy-MM-dd'T'HH:mm:ss.SSSSSS")
        ).filter(col("timestamp").isNotNull())  # Remove records with invalid timestamps
        
        return parsed_df
    
    def _clean_and_validate_data(self, df):
        """
        Apply data cleaning and validation rules specific to industrial IoT data.
        This step ensures data quality and removes obvious sensor errors.
        
        Args:
            df: Parsed DataFrame
            
        Returns:
            Cleaned DataFrame with validation flags
        """
        # Define reasonable ranges for industrial sensors (these would be calibrated for specific equipment)
        TEMP_MIN, TEMP_MAX = -50.0, 150.0  # Temperature in Celsius
        VIBRATION_MIN, VIBRATION_MAX = 0.0, 50.0  # Vibration in m/s²
        PRESSURE_MIN, PRESSURE_MAX = 0.0, 100.0  # Pressure in bar
        
        # Apply validation rules and create quality flags
        cleaned_df = df.withColumn(
            "temp_valid", 
            (col("temperature").between(TEMP_MIN, TEMP_MAX))
        ).withColumn(
            "vibration_valid", 
            (col("vibration").between(VIBRATION_MIN, VIBRATION_MAX))
        ).withColumn(
            "pressure_valid", 
            (col("pressure").between(PRESSURE_MIN, PRESSURE_MAX))
        ).withColumn(
            "overall_quality",
            when(col("temp_valid") & col("vibration_valid") & col("pressure_valid"), "GOOD")
            .when(col("data_quality") == "ANOMALY", "ANOMALY")
            .otherwise("POOR")
        )
        
        # Add processing metadata
        cleaned_df = cleaned_df.withColumn(
            "processed_at", current_timestamp()
        ).withColumn(
            "processing_date", current_date()
        )
        
        return cleaned_df
    
    def _detect_anomalies(self, df):
        """
        Implement anomaly detection logic for industrial equipment monitoring.
        This uses statistical methods to identify unusual sensor patterns that might indicate problems.
        
        Args:
            df: Cleaned DataFrame
            
        Returns:
            DataFrame with anomaly detection results
        """
        # Calculate rolling statistics for anomaly detection
        # We use a time-based window to calculate moving averages and standard deviations
        window_spec = Window.partitionBy("sensor_id").orderBy("timestamp") \
            .rowsBetween(-10, 0)  # Look at last 10 readings for each sensor
        
        anomaly_df = df.withColumn(
            "temp_rolling_avg",
            avg("temperature").over(window_spec)
        ).withColumn(
            "temp_rolling_stddev",
            stddev("temperature").over(window_spec)
        ).withColumn(
            "vibration_rolling_avg",
            avg("vibration").over(window_spec)
        ).withColumn(
            "pressure_rolling_avg",
            avg("pressure").over(window_spec)
        )
        
        # Detect temperature anomalies (readings more than 2 standard deviations from mean)
        anomaly_df = anomaly_df.withColumn(
            "temp_anomaly",
            when(
                abs(col("temperature") - col("temp_rolling_avg")) > 
                (2 * coalesce(col("temp_rolling_stddev"), lit(1.0))), 
                true
            ).otherwise(false)
        )
        
        # Detect vibration spikes (sudden increases that might indicate mechanical issues)
        anomaly_df = anomaly_df.withColumn(
            "vibration_spike",
            when(col("vibration") > col("vibration_rolling_avg") * 2.0, true)
            .otherwise(false)
        )
        
        # Detect pressure anomalies (both high and low pressure can indicate problems)
        anomaly_df = anomaly_df.withColumn(
            "pressure_anomaly",
            when(
                (col("pressure") > col("pressure_rolling_avg") * 1.5) |
                (col("pressure") < col("pressure_rolling_avg") * 0.5),
                true
            ).otherwise(false)
        )
        
        # Create overall anomaly flag
        anomaly_df = anomaly_df.withColumn(
            "anomaly_detected",
            col("temp_anomaly") | col("vibration_spike") | col("pressure_anomaly")
        )
        
        return anomaly_df
    
    def _create_aggregated_metrics(self, df):
        """
        Create time-based aggregations for dashboard and analysis purposes.
        These aggregations provide summary statistics that are useful for monitoring trends.
        
        Args:
            df: DataFrame with anomaly detection
            
        Returns:
            DataFrame with aggregated metrics
        """
        # Create 5-minute time windows for aggregation
        # This provides a good balance between real-time insights and data reduction
        aggregated_df = df.groupBy(
            window(col("timestamp"), "5 minutes").alias("time_window"),
            col("sensor_id"),
            col("location"),
            col("equipment_type")
        ).agg(
            # Statistical aggregations for each sensor parameter
            avg("temperature").alias("avg_temperature"),
            min("temperature").alias("min_temperature"),
            max("temperature").alias("max_temperature"),
            avg("vibration").alias("avg_vibration"),
            max("vibration").alias("max_vibration"),
            avg("pressure").alias("avg_pressure"),
            min("pressure").alias("min_pressure"),
            max("pressure").alias("max_pressure"),
            
            # Count metrics for data quality monitoring
            count("*").alias("total_readings"),
            sum(when(col("overall_quality") == "GOOD", 1).otherwise(0)).alias("good_readings"),
            sum(when(col("anomaly_detected"), 1).otherwise(0)).alias("anomaly_count"),
            
            # Latest status information
            last("machine_status").alias("latest_status"),
            max("processed_at").alias("last_processed")
        )
        
        # Calculate data quality percentage
        aggregated_df = aggregated_df.withColumn(
            "data_quality_pct",
            round((col("good_readings") / col("total_readings") * 100), 2)
        )
        
        # Extract window start and end times for easier querying
        aggregated_df = aggregated_df.withColumn(
            "window_start", col("time_window.start")
        ).withColumn(
            "window_end", col("time_window.end")
        ).drop("time_window")
        
        return aggregated_df
    
    def _write_to_iceberg(self, df, table_name, checkpoint_location):
        """
        Write streaming data to Iceberg table with proper configuration.
        Iceberg provides ACID transactions and efficient storage for our lakehouse architecture.
        
        Args:
            df: DataFrame to write
            table_name: Target Iceberg table name
            checkpoint_location: Checkpoint directory for fault tolerance
            
        Returns:
            Streaming query object
        """
        try:
            # Configure the streaming write operation with Iceberg format
            query = df.writeStream \
                .format("iceberg") \
                .outputMode("append") \
                .option("checkpointLocation", checkpoint_location) \
                .option("path", f"s3a://lakehouse/warehouse/{table_name}") \
                .trigger(processingTime="30 seconds") \
                .start(f"nessie.{table_name}")
            
            logger.info(f"Started streaming to Iceberg table: {table_name}")
            return query
            
        except Exception as e:
            logger.error(f"Failed to write to Iceberg table {table_name}: {e}")
            raise
    
    def _create_iceberg_tables(self):
        """
        Create Iceberg tables with proper schema and partitioning strategy.
        This sets up the storage layer for our processed data.
        """
        try:
            # Create raw sensor data table
            self.spark.sql("""
                CREATE TABLE IF NOT EXISTS nessie.raw_sensor_data (
                    sensor_id STRING,
                    timestamp TIMESTAMP,
                    temperature DOUBLE,
                    vibration DOUBLE,
                    pressure DOUBLE,
                    machine_status STRING,
                    location STRING,
                    equipment_type STRING,
                    data_quality STRING,
                    temp_valid BOOLEAN,
                    vibration_valid BOOLEAN,
                    pressure_valid BOOLEAN,
                    overall_quality STRING,
                    temp_rolling_avg DOUBLE,
                    temp_rolling_stddev DOUBLE,
                    vibration_rolling_avg DOUBLE,
                    pressure_rolling_avg DOUBLE,
                    temp_anomaly BOOLEAN,
                    vibration_spike BOOLEAN,
                    pressure_anomaly BOOLEAN,
                    anomaly_detected BOOLEAN,
                    processed_at TIMESTAMP,
                    processing_date DATE
                ) USING iceberg
                PARTITIONED BY (processing_date)
                TBLPROPERTIES (
                    'write.target-file-size-bytes'='134217728',
                    'write.parquet.compression-codec'='snappy'
                )
            """)
            
            # Create aggregated metrics table
            self.spark.sql("""
                CREATE TABLE IF NOT EXISTS nessie.sensor_metrics_5min (
                    window_start TIMESTAMP,
                    window_end TIMESTAMP,
                    sensor_id STRING,
                    location STRING,
                    equipment_type STRING,
                    avg_temperature DOUBLE,
                    min_temperature DOUBLE,
                    max_temperature DOUBLE,
                    avg_vibration DOUBLE,
                    max_vibration DOUBLE,
                    avg_pressure DOUBLE,
                    min_pressure DOUBLE,
                    max_pressure DOUBLE,
                    total_readings BIGINT,
                    good_readings BIGINT,
                    anomaly_count BIGINT,
                    data_quality_pct DOUBLE,
                    latest_status STRING,
                    last_processed TIMESTAMP
                ) USING iceberg
                PARTITIONED BY (date(window_start))
                TBLPROPERTIES (
                    'write.target-file-size-bytes'='67108864',
                    'write.parquet.compression-codec'='snappy'
                )
            """)
            
            logger.info("Iceberg tables created successfully")
            
        except Exception as e:
            logger.error(f"Failed to create Iceberg tables: {e}")
            raise
    
    def run_streaming_pipeline(self, kafka_servers="kafka:29092", topic="industrial-iot-data"):
        """
        Execute the complete streaming pipeline from Kafka to Iceberg.
        This orchestrates all the processing steps in the correct order.
        
        Args:
            kafka_servers: Kafka bootstrap servers
            topic: Kafka topic to consume from
        """
        try:
            logger.info("Starting Industrial IoT Streaming Pipeline...")
            
            # Step 1: Create Iceberg tables if they don't exist
            self._create_iceberg_tables()
            
            # Step 2: Read data from Kafka
            kafka_df = self._read_kafka_stream(kafka_servers, topic)
            
            # Step 3: Parse JSON data and apply schema
            parsed_df = self._parse_json_data(kafka_df)
            
            # Step 4: Clean and validate the data
            cleaned_df = self._clean_and_validate_data(parsed_df)
            
            # Step 5: Apply anomaly detection
            anomaly_df = self._detect_anomalies(cleaned_df)
            
            # Step 6: Create aggregated metrics
            aggregated_df = self._create_aggregated_metrics(cleaned_df)
            
            # Step 7: Write raw data to Iceberg
            raw_data_query = self._write_to_iceberg(
                anomaly_df, 
                "raw_sensor_data", 
                "/tmp/spark-checkpoints/raw_data"
            )
            
            # Step 8: Write aggregated data to Iceberg
            metrics_query = self._write_to_iceberg(
                aggregated_df, 
                "sensor_metrics_5min", 
                "/tmp/spark-checkpoints/metrics"
            )
            
            # Step 9: Monitor the streaming queries
            logger.info("Streaming pipeline started successfully")
            logger.info("Monitoring streaming queries... Press Ctrl+C to stop")
            
            # Keep the application running and monitor query status
            try:
                while True:
                    # Check query status every 30 seconds
                    import time
                    time.sleep(30)
                    
                    if not raw_data_query.isActive:
                        logger.error("Raw data query stopped unexpectedly")
                        break
                    
                    if not metrics_query.isActive:
                        logger.error("Metrics query stopped unexpectedly")
                        break
                    
                    # Log progress information
                    raw_progress = raw_data_query.lastProgress
                    metrics_progress = metrics_query.lastProgress
                    
                    if raw_progress:
                        logger.info(f"Raw data - Batch: {raw_progress.get('batchId', 'N/A')}, "
                                  f"Input rows: {raw_progress.get('inputRowsPerSecond', 'N/A')}")
                    
                    if metrics_progress:
                        logger.info(f"Metrics - Batch: {metrics_progress.get('batchId', 'N/A')}, "
                                  f"Input rows: {metrics_progress.get('inputRowsPerSecond', 'N/A')}")
                        
            except KeyboardInterrupt:
                logger.info("Stopping streaming pipeline...")
                raw_data_query.stop()
                metrics_query.stop()
                
                # Wait for graceful shutdown
                raw_data_query.awaitTermination(timeout=30)
                metrics_query.awaitTermination(timeout=30)
                
                logger.info("Streaming pipeline stopped successfully")
            
        except Exception as e:
            logger.error(f"Streaming pipeline failed: {e}")
            raise
        finally:
            if self.spark:
                self.spark.stop()
    
    def run_batch_analysis(self):
        """
        Run batch analysis on stored data for deeper insights.
        This demonstrates how to query the Iceberg tables for analysis.
        """
        try:
            logger.info("Running batch analysis on stored data...")
            
            # Analyze temperature trends by location
            temp_trends = self.spark.sql("""
                SELECT 
                    location,
                    equipment_type,
                    DATE(window_start) as analysis_date,
                    AVG(avg_temperature) as daily_avg_temp,
                    MAX(max_temperature) as daily_max_temp,
                    MIN(min_temperature) as daily_min_temp,
                    SUM(anomaly_count) as total_anomalies
                FROM nessie.sensor_metrics_5min
                WHERE window_start >= current_date() - INTERVAL 7 DAYS
                GROUP BY location, equipment_type, DATE(window_start)
                ORDER BY analysis_date DESC, location
            """)
            
            logger.info("Temperature trends analysis:")
            temp_trends.show(20, truncate=False)
            
            # Analyze equipment performance
            equipment_performance = self.spark.sql("""
                SELECT 
                    sensor_id,
                    location,
                    equipment_type,
                    COUNT(*) as total_windows,
                    AVG(data_quality_pct) as avg_data_quality,
                    SUM(anomaly_count) as total_anomalies,
                    MAX(max_vibration) as peak_vibration,
                    AVG(avg_pressure) as avg_pressure
                FROM nessie.sensor_metrics_5min
                WHERE window_start >= current_date() - INTERVAL 1 DAYS
                GROUP BY sensor_id, location, equipment_type
                HAVING total_anomalies > 0
                ORDER BY total_anomalies DESC
            """)
            
            logger.info("Equipment performance analysis (sensors with anomalies):")
            equipment_performance.show(20, truncate=False)
            
            # Find correlations between sensor readings
            correlations = self.spark.sql("""
                SELECT 
                    location,
                    equipment_type,
                    corr(avg_temperature, avg_vibration) as temp_vibration_corr,
                    corr(avg_pressure, avg_vibration) as pressure_vibration_corr,
                    corr(avg_temperature, avg_pressure) as temp_pressure_corr
                FROM nessie.sensor_metrics_5min
                WHERE window_start >= current_date() - INTERVAL 1 DAYS
                GROUP BY location, equipment_type
                HAVING COUNT(*) > 10
            """)
            
            logger.info("Sensor correlation analysis:")
            correlations.show(truncate=False)
            
        except Exception as e:
            logger.error(f"Batch analysis failed: {e}")
            raise

def main():
    """
    Main function to run the Industrial IoT processing pipeline.
    This can be configured to run either streaming or batch analysis.
    """
    import argparse
    
    parser = argparse.ArgumentParser(description='Industrial IoT Data Processor')
    parser.add_argument('--mode', choices=['streaming', 'batch'], default='streaming',
                       help='Processing mode (default: streaming)')
    parser.add_argument('--kafka-servers', default='kafka:29092',
                       help='Kafka bootstrap servers (default: kafka:29092)')
    parser.add_argument('--topic', default='industrial-iot-data',
                       help='Kafka topic name (default: industrial-iot-data)')
    
    args = parser.parse_args()
    
    # Initialize the processor
    processor = IndustrialIoTProcessor()
    
    try:
        if args.mode == 'streaming':
            # Run the streaming pipeline
            processor.run_streaming_pipeline(
                kafka_servers=args.kafka_servers,
                topic=args.topic
            )
        else:
            # Run batch analysis
            processor.run_batch_analysis()
            
    except Exception as e:
        logger.error(f"Application failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())

# Example usage:
# python spark_streaming.py --mode streaming --kafka-servers localhost:9092
# python spark_streaming.py --mode batch