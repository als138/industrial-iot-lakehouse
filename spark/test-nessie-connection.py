from pyspark.sql import SparkSession

def test_nessie():
    try:
        print("🧪 Testing Nessie connection...")
        
        spark = SparkSession.builder \
            .appName("TestNessie") \
            .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,org.projectnessie.spark.extensions.NessieSparkSessionExtensions") \
            .config("spark.sql.catalog.nessie", "org.apache.iceberg.spark.SparkCatalog") \
            .config("spark.sql.catalog.nessie.catalog-impl", "org.apache.iceberg.nessie.NessieCatalog") \
            .config("spark.sql.catalog.nessie.uri", "http://nessie:19120/api/v1") \
            .config("spark.sql.catalog.nessie.ref", "main") \
            .config("spark.sql.catalog.nessie.warehouse", "s3a://warehouse/") \
            .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000") \
            .config("spark.hadoop.fs.s3a.access.key", "minioadmin") \
            .config("spark.hadoop.fs.s3a.secret.key", "minioadmin") \
            .config("spark.hadoop.fs.s3a.path.style.access", "true") \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .getOrCreate()
        
        print("✅ Spark session with Nessie created!")
        
        # Test catalogs
        print("📋 Available catalogs:")
        spark.sql("SHOW CATALOGS").show()
        
        # Test Nessie database creation
        print("🏗 Creating test database in Nessie...")
        spark.sql("CREATE DATABASE IF NOT EXISTS nessie.test_db")
        
        print("🎉 Nessie connection test successful!")
        
    except Exception as e:
        print(f"❌ Nessie test failed: {e}")
        import traceback
        traceback.print_exc()

if name == "main":
    test_nessie()
