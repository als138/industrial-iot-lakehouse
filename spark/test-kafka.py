from kafka import KafkaProducer, KafkaConsumer
import json

def test_kafka_connection():
    try:
        print("🧪 Testing Kafka connection...")
        
        # Test producer connection
        producer = KafkaProducer(
            bootstrap_servers=['kafka:29092'],
            value_serializer=lambda x: json.dumps(x).encode('utf-8'),
            api_version=(0, 10, 1)
        )
        
        # Send a test message
        test_message = {'test': 'connection', 'timestamp': '2024-01-01T00:00:00'}
        future = producer.send('iot-sensor-data', value=test_message)
        result = future.get(timeout=10)
        
        print("✅ Successfully connected to Kafka!")
        print(f"✅ Test message sent to partition {result.partition} at offset {result.offset}")
        
        producer.close()
        return True
        
    except Exception as e:
        print(f"❌ Kafka connection failed: {e}")
        return False

if __name__ == "__main__":
    test_kafka_connection()
