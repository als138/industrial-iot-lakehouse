from pyspark.sql import SparkSession

def test_iceberg():
    try:
        print("🧪 Testing Iceberg setup...")
        
        spark = SparkSession.builder \
            .appName("TestIceberg") \
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
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .getOrCreate()
        
        print("✅ Spark session created")
        
        # Test catalogs
        print("📋 Available catalogs:")
        spark.sql("SHOW CATALOGS").show()
        
        # Test Nessie connection
        print("🏗 Creating test database...")
        spark.sql("CREATE DATABASE IF NOT EXISTS nessie.test_db")
        
        print("🎉 Iceberg test successful!")
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if name == "main":  # ✅ Fixed: was if name == "main":
    test_iceberg()
