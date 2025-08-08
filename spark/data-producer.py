import pandas as pd
import json
import time
from kafka import KafkaProducer
from datetime import datetime
import random

class IoTDataProducer:
    def __init__(self):  # ✅ Fixed: was def init(self):
        # Use simple container name for Kafka
        kafka_servers = ['kafka:29092']
        print(f"📡 Connecting to Kafka at: {kafka_servers}")
        
        self.producer = KafkaProducer(
            bootstrap_servers=kafka_servers,
            value_serializer=lambda x: json.dumps(x).encode('utf-8'),
            retries=5,
            request_timeout_ms=30000,
            api_version=(0, 10, 1)
        )
        self.topic = 'iot-sensor-data'
        print(f"✅ Connected to Kafka topic: {self.topic}")
    
    def load_dataset(self, file_path):
        """Load the industrial fault detection dataset"""
        return pd.read_csv(file_path)
    
    def simulate_real_time_data(self, df):
        """Simulate real-time data streaming from the dataset"""
        print(f"🚀 Starting to stream {len(df)} records...")
        print("=" * 60)
        
        for index, row in df.iterrows():
            try:
                # Use original timestamp from CSV
                original_timestamp = pd.to_datetime(row['Timestamp'])
                
                # Create IoT message
                message = {
                    'timestamp': original_timestamp.isoformat(),
                    'machine_id': f"machine_{random.randint(1, 5)}",
                    'vibration_mms': float(row['Vibration (mm/s)']),
                    'temperature_c': float(row['Temperature (°C)']),
                    'pressure_bar': float(row['Pressure (bar)']),
                    'rms_vibration': float(row['RMS Vibration']),
                    'mean_temp': float(row['Mean Temp']),
                    'fault_label': int(row['Fault Label'])
                }
                
                # Send to Kafka
                future = self.producer.send(self.topic, value=message)
                result = future.get(timeout=10)
                
                fault_indicator = "⚠️ FAULT" if message['fault_label'] > 0 else "✅ OK"
                print(f"📤 [{index + 1:3d}/{len(df)}] {fault_indicator} | Machine: {message['machine_id']} | Temp: {message['temperature_c']:.1f}°C | Vibration: {message['vibration_mms']:.2f} | Pressure: {message['pressure_bar']:.2f}")
                
                # Simulate streaming delay
                time.sleep(2)
                
            except Exception as e:
                print(f"❌ Error sending record {index}: {e}")
                continue
    
    def close(self):
        self.producer.close()
        print("🔒 Producer closed.")

if __name__ == "__main__":  # ✅ Fixed: was if name == "main":
    try:
        producer = IoTDataProducer()
        df = producer.load_dataset('/opt/spark/data/industrial_fault_detection_data_1000.csv')
        print(f"📁 Loaded {len(df)} records from dataset")
        producer.simulate_real_time_data(df)
        producer.close()
        print("🎉 Data streaming completed successfully!")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
