import pandas as pd
import json
import time
from kafka import KafkaProducer
from datetime import datetime, timedelta
import random

class IoTDataProducer:
    def __init__(self):
        self.producer = KafkaProducer(
            bootstrap_servers=['localhost:9092'],
            value_serializer=lambda x: json.dumps(x).encode('utf-8')
        )
        self.topic = 'iot-sensor-data'
    
    def load_dataset(self, file_path):
        """Load the industrial fault detection dataset"""
        return pd.read_csv(file_path)
    
    def simulate_real_time_data(self, df):
        """Simulate real-time data streaming from the dataset"""
        for index, row in df.iterrows():
            # Option 1: Use original timestamp (RECOMMENDED)
            original_timestamp = pd.to_datetime(row['Timestamp'])
            
            # Option 2: Use current time for real-time simulation
            # current_time = datetime.now()
            
            # Create IoT message using original timestamp
            message = {
                'timestamp': original_timestamp.isoformat(),
                # 'original_timestamp': original_timestamp.isoformat(),  # Keep original for reference
                'machine_id': f"machine_{random.randint(1, 10)}",
                'vibration_mms': float(row['Vibration (mm/s)']),
                'temperature_c': float(row['Temperature (°C)']),
                'pressure_bar': float(row['Pressure (bar)']),
                'rms_vibration': float(row['RMS Vibration']),
                'mean_temp': float(row['Mean Temp']),
                'fault_label': int(row['Fault Label'])
            }
            
            # Send to Kafka
            self.producer.send(self.topic, value=message)
            print(f"Sent message {index + 1}: {message}")
            
            # Simulate real-time delay
            time.sleep(2)
    
    def close(self):
        self.producer.close()

if __name__ == "__main__":
    producer = IoTDataProducer()
    df = producer.load_dataset('data/industrial_fault_detection.csv')
    producer.simulate_real_time_data(df)
    producer.close()