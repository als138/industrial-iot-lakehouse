#!/usr/bin/env python3
"""
Industrial IoT Data Producer for Kafka
This script simulates real-time sensor data streaming by reading from the dataset
and publishing messages to Kafka topics in batches, mimicking industrial IoT behavior.
"""

import json
import time
import pandas as pd
from kafka import KafkaProducer
from datetime import datetime, timedelta
import logging
import argparse
import random
from typing import Dict, Any

# Configure logging for monitoring producer activity
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class IndustrialIoTProducer:
    """
    Producer class that handles streaming industrial IoT sensor data to Kafka.
    This simulates the behavior of real industrial sensors sending continuous data.
    """
    
    def __init__(self, kafka_servers: str = 'localhost:9092', topic: str = 'industrial-iot-data'):
        """
        Initialize the Kafka producer with connection settings.
        
        Args:
            kafka_servers: Kafka bootstrap servers address
            topic: Kafka topic name for industrial data
        """
        self.kafka_servers = kafka_servers
        self.topic = topic
        self.producer = None
        self._setup_producer()
    
    def _setup_producer(self):
        """
        Configure the Kafka producer with JSON serialization and error handling.
        We use JSON for easy data interchange between systems.
        """
        try:
            self.producer = KafkaProducer(
                bootstrap_servers=[self.kafka_servers],
                # Serialize data as JSON for structured message format
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda k: str(k).encode('utf-8') if k else None,
                # Configure for reliable delivery in production scenarios
                acks='all',  # Wait for acknowledgment from all replicas
                retries=3,   # Retry failed sends up to 3 times
                batch_size=16384,  # Batch messages for efficiency
                linger_ms=10,      # Wait up to 10ms for batching
                buffer_memory=33554432  # 32MB buffer
            )
            logger.info(f"Kafka producer initialized successfully for topic: {self.topic}")
        except Exception as e:
            logger.error(f"Failed to initialize Kafka producer: {e}")
            raise
    
    def _add_realistic_noise(self, row: pd.Series) -> Dict[str, Any]:
        """
        Add realistic industrial sensor noise and timing to simulate real-world conditions.
        Industrial sensors often have small variations and occasional spikes.
        
        Args:
            row: Original data row from dataset
            
        Returns:
            Enhanced data with realistic sensor characteristics
        """
        # Add small random variations to simulate sensor noise (±1% typically)
        temperature_noise = random.uniform(-0.5, 0.5)
        vibration_noise = random.uniform(-0.1, 0.1)
        pressure_noise = random.uniform(-0.2, 0.2)
        
        # Occasionally introduce sensor spikes (happens in real industrial environments)
        spike_probability = 0.02  # 2% chance of a reading spike
        temperature_spike = random.uniform(1.0, 3.0) if random.random() < spike_probability else 0
        vibration_spike = random.uniform(0.5, 2.0) if random.random() < spike_probability else 0
        pressure_spike = random.uniform(1.0, 4.0) if random.random() < spike_probability else 0
        
        # Create enriched message with timestamp and sensor metadata
        message = {
            'sensor_id': f"sensor_{int(row.get('sensor_id', random.randint(1000, 9999)))}",
            'timestamp': datetime.now().isoformat(),
            'temperature': round(float(row.get('temperature', 0)) + temperature_noise + temperature_spike, 2),
            'vibration': round(float(row.get('vibration', 0)) + vibration_noise + vibration_spike, 3),
            'pressure': round(float(row.get('pressure', 0)) + pressure_noise + pressure_spike, 2),
            'machine_status': row.get('machine_status', 'NORMAL'),
            # Add metadata that would be present in real IoT systems
            'location': row.get('location', f'Plant_A_Unit_{random.randint(1, 10)}'),
            'equipment_type': row.get('equipment_type', 'Industrial_Pump'),
            'data_quality': 'GOOD' if all([temperature_spike == 0, vibration_spike == 0, pressure_spike == 0]) else 'ANOMALY'
        }
        
        return message
    
    def load_and_stream_data(self, csv_file_path: str, batch_size: int = 10, delay_seconds: float = 2.0):
        """
        Load dataset and stream it to Kafka in batches to simulate real-time data flow.
        This approach mimics how industrial systems send data in regular intervals.
        
        Args:
            csv_file_path: Path to the industrial IoT dataset
            batch_size: Number of records to send in each batch
            delay_seconds: Delay between batches (simulates sensor reading frequency)
        """
        try:
            # Load the dataset - in production, this would be replaced by actual sensor readings
            logger.info(f"Loading dataset from: {csv_file_path}")
            df = pd.read_csv(csv_file_path)
            logger.info(f"Loaded {len(df)} records from dataset")
            
            # Process and stream data in batches
            total_batches = len(df) // batch_size + (1 if len(df) % batch_size > 0 else 0)
            messages_sent = 0
            
            for batch_num in range(total_batches):
                start_idx = batch_num * batch_size
                end_idx = min((batch_num + 1) * batch_size, len(df))
                batch_data = df.iloc[start_idx:end_idx]
                
                # Send each record in the batch
                for _, row in batch_data.iterrows():
                    try:
                        # Enhance data with realistic sensor characteristics
                        message = self._add_realistic_noise(row)
                        
                        # Use sensor_id as the key for proper partitioning
                        # This ensures data from the same sensor goes to the same partition
                        message_key = message['sensor_id']
                        
                        # Send message to Kafka topic
                        future = self.producer.send(self.topic, key=message_key, value=message)
                        
                        # Optional: wait for confirmation (comment out for higher throughput)
                        # future.get(timeout=10)
                        
                        messages_sent += 1
                        
                    except Exception as e:
                        logger.error(f"Failed to send message: {e}")
                        continue
                
                # Flush producer to ensure all messages are sent
                self.producer.flush()
                
                batch_progress = (batch_num + 1) / total_batches * 100
                logger.info(f"Batch {batch_num + 1}/{total_batches} sent ({batch_progress:.1f}%) - "
                           f"Messages sent: {messages_sent}")
                
                # Simulate real-time data flow with controlled delay
                if batch_num < total_batches - 1:  # Don't delay after the last batch
                    time.sleep(delay_seconds)
            
            logger.info(f"Successfully streamed {messages_sent} messages to topic '{self.topic}'")
            
        except FileNotFoundError:
            logger.error(f"Dataset file not found: {csv_file_path}")
            raise
        except pd.errors.EmptyDataError:
            logger.error("The CSV file appears to be empty")
            raise
        except Exception as e:
            logger.error(f"Unexpected error during data streaming: {e}")
            raise
    
    def send_test_message(self):
        """
        Send a test message to verify Kafka connectivity.
        Useful for debugging connection issues.
        """
        test_message = {
            'sensor_id': 'test_sensor_001',
            'timestamp': datetime.now().isoformat(),
            'temperature': 25.5,
            'vibration': 0.3,
            'pressure': 1.2,
            'machine_status': 'NORMAL',
            'location': 'TEST_PLANT',
            'equipment_type': 'TEST_EQUIPMENT',
            'data_quality': 'GOOD',
            'message_type': 'TEST'
        }
        
        try:
            future = self.producer.send(self.topic, value=test_message)
            future.get(timeout=10)  # Wait for confirmation
            logger.info("Test message sent successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to send test message: {e}")
            return False
    
    def close(self):
        """Clean up producer resources."""
        if self.producer:
            self.producer.flush()
            self.producer.close()
            logger.info("Kafka producer closed successfully")

def main():
    """
    Main function to handle command line arguments and start the producer.
    This allows flexible configuration for different environments.
    """
    parser = argparse.ArgumentParser(description='Industrial IoT Data Producer for Kafka')
    parser.add_argument('--csv-file', required=True, help='Path to the industrial IoT CSV dataset')
    parser.add_argument('--kafka-servers', default='localhost:9092', 
                       help='Kafka bootstrap servers (default: localhost:9092)')
    parser.add_argument('--topic', default='industrial-iot-data', 
                       help='Kafka topic name (default: industrial-iot-data)')
    parser.add_argument('--batch-size', type=int, default=10, 
                       help='Number of messages per batch (default: 10)')
    parser.add_argument('--delay', type=float, default=2.0, 
                       help='Delay between batches in seconds (default: 2.0)')
    parser.add_argument('--test-only', action='store_true', 
                       help='Send only a test message and exit')
    
    args = parser.parse_args()
    
    # Initialize producer
    producer = IndustrialIoTProducer(
        kafka_servers=args.kafka_servers,
        topic=args.topic
    )
    
    try:
        if args.test_only:
            # Test mode - send one message and exit
            logger.info("Running in test mode...")
            success = producer.send_test_message()
            if success:
                logger.info("Test completed successfully")
            else:
                logger.error("Test failed")
        else:
            # Production mode - stream the entire dataset
            logger.info("Starting data streaming...")
            producer.load_and_stream_data(
                csv_file_path=args.csv_file,
                batch_size=args.batch_size,
                delay_seconds=args.delay
            )
            logger.info("Data streaming completed")
            
    except KeyboardInterrupt:
        logger.info("Streaming interrupted by user")
    except Exception as e:
        logger.error(f"Producer failed: {e}")
        return 1
    finally:
        producer.close()
    
    return 0

if __name__ == "__main__":
    exit(main())

# Example usage:
# python kafka_producer.py --csv-file /path/to/industrial_iot_dataset.csv --batch-size 20 --delay 1.5
# python kafka_producer.py --csv-file dataset.csv --test-only