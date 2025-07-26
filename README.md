# Industrial IoT Lakehouse Architecture

یک پیاده‌سازی کامل از معماری Lakehouse برای پردازش و تحلیل داده‌های صنعتی IoT با استفاده از Apache Kafka، Spark، Iceberg، Dremio و Superset.

## 📋 فهرست مطالب

- [نمای کلی پروژه](#نمای-کلی-پروژه)
- [معماری سیستم](#معماری-سیستم)
- [پیش‌نیازها](#پیش‌نیازها)
- [نصب و راه‌اندازی](#نصب-و-راه‌اندازی)
- [ساختار پروژه](#ساختار-پروژه)
- [استفاده از سیستم](#استفاده-از-سیستم)
- [مدیریت سیستم](#مدیریت-سیستم)
- [عیب‌یابی](#عیب‌یابی)
- [پیکربندی پیشرفته](#پیکربندی-پیشرفته)

## 🎯 نمای کلی پروژه

این پروژه یک سیستم کامل Lakehouse برای پردازش داده‌های سنسورهای صنعتی است که شامل:

- **جمع‌آوری داده**: دریافت داده‌های real-time از سنسورهای دما، ارتعاش و فشار
- **پردازش جریانی**: تحلیل و پردازش داده‌ها به صورت real-time
- **ذخیره‌سازی**: نگهداری داده‌ها در فرمت Iceberg با قابلیت version control
- **تحلیل**: کوئری‌های تحلیلی با عملکرد بالا
- **تجسم**: داشبوردهای تعاملی برای نظارت بر تجهیزات

### ویژگی‌های کلیدی

✅ **Real-time Processing**: پردازش فوری داده‌های سنسورها  
✅ **Anomaly Detection**: تشخیص خودکار ناهنجاری‌ها  
✅ **Data Quality Monitoring**: نظارت بر کیفیت داده‌ها  
✅ **Scalable Architecture**: معماری قابل گسترش  
✅ **Interactive Dashboards**: داشبوردهای تعاملی  
✅ **ACID Transactions**: تراکنش‌های ACID با Iceberg  

## 🏗️ معماری سیستم

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   IoT Sensors   │───▶│   Kafka Topic   │───▶│ Spark Streaming │
│   (CSV Data)    │    │industrial-iot-  │    │   Processor     │
└─────────────────┘    │     data        │    └─────────────────┘
                       └─────────────────┘              │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Superset     │◀───│     Dremio      │◀───│ Iceberg Tables  │
│   Dashboards    │    │  Query Engine   │    │   (MinIO S3)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                 ▲                       │
                                 │                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │ Nessie Catalog  │    │   Data Lake     │
                       │ (Version Ctrl)  │    │   Storage       │
                       └─────────────────┘    └─────────────────┘
```

### کامپوننت‌های سیستم

| کامپوننت | نقش | پورت |
|-----------|-----|------|
| **Apache Kafka** | Message Streaming | 9092 |
| **Apache Spark** | Stream Processing | 8080, 7077 |
| **Apache Iceberg** | Table Format | - |
| **Nessie** | Data Catalog | 19120 |
| **MinIO** | Object Storage | 9000, 9001 |
| **Dremio** | Query Engine | 9047 |
| **Apache Superset** | Visualization | 8088 |

## 🔧 پیش‌نیازها

### نرم‌افزار مورد نیاز

- **Python 3.8+** (با pip)
- **Docker 20.0+** و Docker Compose
- **Git** (برای clone کردن پروژه)
- **curl** (برای health checks)

### منابع سیستم

| منبع | حداقل | توصیه شده |
|------|--------|-----------|
| **RAM** | 8 GB | 16 GB |
| **CPU** | 4 cores | 8 cores |
| **Storage** | 20 GB | 50 GB |
| **Network** | 100 Mbps | 1 Gbps |

### بررسی پیش‌نیازها

```bash
# بررسی Python
python3 --version

# بررسی Docker
docker --version
docker-compose --version

# بررسی منابع سیستم
free -h
df -h
```

## 🚀 نصب و راه‌اندازی

### روش 1: نصب خودکار (توصیه شده)

```bash
# 1. Clone کردن پروژه
git clone <repository-url>
cd industrial-iot-lakehouse

# 2. اجرای اسکریپت نصب
chmod +x setup.sh
./setup.sh

# 3. منتظر تکمیل نصب بمانید (5-15 دقیقه)
```

### روش 2: نصب گام به گام

```bash
# 1. ایجاد ساختار پروژه
mkdir -p data/{raw,processed,sample}
mkdir -p src/{producer,streaming,visualization}
mkdir -p logs/{kafka,spark,application}

# 2. ایجاد محیط مجازی Python
python3 -m venv lakehouse-env
source lakehouse-env/bin/activate

# 3. نصب وابستگی‌های Python
pip install -r requirements.txt

# 4. دانلود JAR های Spark
chmod +x spark_jars_setup.sh
./spark_jars_setup.sh

# 5. راه‌اندازی سرویس‌های Docker
docker-compose up -d

# 6. انتظار برای آماده شدن سرویس‌ها
sleep 60

# 7. تنظیم MinIO
mc alias set local http://localhost:9000 minioadmin minioadmin123
mc mb local/lakehouse
mc mb local/lakehouse/warehouse

# 8. ایجاد topic های Kafka
docker-compose exec kafka kafka-topics.sh \
  --create --topic industrial-iot-data \
  --bootstrap-server localhost:9092 \
  --partitions 3 --replication-factor 1
```

### روش 3: نصب سریع (برای تست)

```bash
# نصب سریع بدون کامپوننت‌های اختیاری
./setup.sh --quick --dev
```

## 📁 ساختار پروژه

```
industrial-iot-lakehouse/
├── 📄 README.md                     # مستندات اصلی
├── 📄 requirements.txt              # وابستگی‌های Python
├── 📄 docker-compose.yml            # پیکربندی سرویس‌ها
├── 📄 setup.sh                      # اسکریپت نصب
├── 📄 manage.sh                     # اسکریپت مدیریت
├── 📄 .env                          # تنظیمات محیطی
│
├── 📂 data/                         # داده‌ها
│   ├── 📂 raw/                      # داده‌های خام
│   ├── 📂 processed/                # داده‌های پردازش شده
│   └── 📂 sample/                   # داده‌های نمونه
│
├── 📂 src/                          # کد اصلی
│   ├── 📂 producer/                 # تولیدکننده Kafka
│   │   └── 📄 kafka_producer.py
│   ├── 📂 streaming/                # پردازشگر Spark
│   │   └── 📄 spark_streaming.py
│   └── 📂 visualization/            # تجسم داده
│       └── 📄 superset_config.py
│
├── 📂 sql/                          # کوئری‌های SQL
│   └── 📄 dremio_queries.sql
│
├── 📂 config/                       # پیکربندی‌ها
├── 📂 scripts/                      # اسکریپت‌های کمکی
├── 📂 docs/                         # مستندات
├── 📂 notebooks/                    # Jupyter notebooks
├── 📂 tests/                        # تست‌ها
└── 📂 logs/                         # لاگ‌ها
```

## 💻 استفاده از سیستم

### دسترسی به رابط‌های کاربری

پس از نصب موفق، سرویس‌ها در آدرس‌های زیر در دسترس هستند:

| سرویس | آدرس | نام کاربری | رمز عبور |
|--------|-------|-------------|----------|
| **MinIO Console** | http://localhost:9001 | minioadmin | minioadmin123 |
| **Dremio Console** | http://localhost:9047 | admin | admin123 |
| **Superset** | http://localhost:8088 | admin | admin |
| **Spark Master UI** | http://localhost:8080 | - | - |
| **Nessie API** | http://localhost:19120/api/v1 | - | - |

### شروع پردازش داده

```bash
# 1. فعال‌سازی محیط Python
source lakehouse-env/bin/activate

# 2. شروع producer
./manage.sh producer start

# 3. شروع streaming processor
./manage.sh streaming start

# 4. بررسی وضعیت
./manage.sh status
```

### مشاهده داده‌ها

```sql
-- در Dremio، کوئری‌های زیر را اجرا کنید:

-- بررسی جداول موجود
SHOW TABLES IN nessie;

-- مشاهده داده‌های خام
SELECT * FROM nessie.raw_sensor_data LIMIT 10;

-- تحلیل میانگین دما به تفکیک مکان
SELECT 
    location,
    AVG(temperature) as avg_temp,
    COUNT(*) as reading_count
FROM nessie.raw_sensor_data
GROUP BY location;
```

## 🔧 مدیریت سیستم

### اسکریپت مدیریت

فایل `manage.sh` ابزاری جامع برای مدیریت سیستم است:

```bash
# نمایش وضعیت کلی سیستم
./manage.sh status

# مدیریت سرویس‌ها
./manage.sh start          # شروع همه سرویس‌ها
./manage.sh stop           # توقف همه سرویس‌ها
./manage.sh restart        # راه‌اندازی مجدد

# مدیریت producer
./manage.sh producer start
./manage.sh producer stop
./manage.sh producer status

# مدیریت streaming
./manage.sh streaming start
./manage.sh streaming stop
./manage.sh streaming status

# مشاهده لاگ‌ها
./manage.sh logs           # همه لاگ‌ها
./manage.sh logs kafka     # لاگ Kafka
./manage.sh logs producer  # لاگ producer

# نظارت real-time
./manage.sh monitor

# بررسی سلامت
./manage.sh health

# پاک‌سازی سیستم
./manage.sh cleanup

# تهیه backup
./manage.sh backup
```

### نظارت بر سیستم

```bash
# نظارت real-time
./manage.sh monitor

# بررسی منابع مصرفی
docker stats

# بررسی وضعیت سرویس‌ها
docker-compose ps

# مشاهده لاگ‌های live
docker-compose logs -f kafka
docker-compose logs -f spark-master
```

## 🔍 عیب‌یابی

### مشکلات رایج و راه‌حل‌ها

#### 1. سرویس‌ها راه‌اندازی نمی‌شوند

```bash
# بررسی وضعیت Docker
docker info

# بررسی منابع سیستم
free -h
df -h

# راه‌اندازی مجدد
docker-compose down
docker-compose up -d
```

#### 2. Producer کار نمی‌کند

```bash
# بررسی لاگ producer
./manage.sh logs producer

# تست اتصال Kafka
docker-compose exec kafka kafka-topics.sh \
  --list --bootstrap-server localhost:9092

# راه‌اندازی مجدد producer
./manage.sh producer restart
```

#### 3. Spark Streaming خطا می‌دهد

```bash
# بررسی لاگ streaming
./manage.sh logs streaming

# بررسی JAR های موجود
ls -la spark-jars/

# تنظیم مجدد متغیرهای محیطی
source set_spark_env.sh
./manage.sh streaming restart
```

#### 4. Dremio به داده‌ها دسترسی ندارد

```bash
# بررسی اتصال MinIO
mc ls local/lakehouse/

# بررسی جداول Iceberg
docker-compose exec spark-master pyspark \
  --jars /path/to/iceberg-jars
```

### لاگ‌های مهم

```bash
# لاگ‌های application
tail -f logs/application/producer.log
tail -f logs/application/streaming.log

# لاگ‌های Docker services
docker-compose logs kafka
docker-compose logs spark-master
docker-compose logs dremio
```

### بازیابی از خرابی

```bash
# پاک‌سازی و راه‌اندازی مجدد
./manage.sh stop
./manage.sh cleanup
docker-compose down -v
docker-compose up -d

# بازگردانی از backup
tar -xzf backup_YYYYMMDD_HHMMSS.tar.gz
# سپس فایل‌های مهم را کپی کنید
```

## ⚙️ پیکربندی پیشرفته

### تنظیمات Performance

#### تنظیمات Kafka

```bash
# در فایل .env
KAFKA_PRODUCER_BATCH_SIZE=32768
KAFKA_PRODUCER_LINGER_MS=5
KAFKA_CONSUMER_MAX_POLL_RECORDS=1000
```

#### تنظیمات Spark

```bash
# در فایل .env
SPARK_EXECUTOR_MEMORY=4g
SPARK_EXECUTOR_CORES=4
SPARK_SQL_SHUFFLE_PARTITIONS=400
```

#### تنظیمات MinIO

```bash
# افزایش performance MinIO
MINIO_CACHE_DRIVES=/tmp/minio-cache
MINIO_CACHE_QUOTA=80
```

### Scaling کردن سیستم

#### افزایش Worker های Spark

```yaml
# در docker-compose.yml
spark-worker-2:
  image: bitnami/spark:3.5
  environment:
    SPARK_MODE: worker
    SPARK_MASTER_URL: spark://spark-master:7077
```

#### افزایش Partition های Kafka

```bash
docker-compose exec kafka kafka-topics.sh \
  --alter --topic industrial-iot-data \
  --partitions 6 \
  --bootstrap-server localhost:9092
```

### Security تنظیمات

#### فعال‌سازی SSL

```bash
# در فایل .env
SSL_ENABLED=true
SSL_CERT_FILE=/path/to/cert.pem
SSL_KEY_FILE=/path/to/key.pem
```

#### تنظیمات Authentication

```bash
# برای Superset
SUPERSET_SECRET_KEY=your-very-secure-secret-key

# برای Dremio
DREMIO_USERNAME=your-admin-user
DREMIO_PASSWORD=your-secure-password
```

## 📊 مثال‌های کاربردی

### تحلیل Anomaly Detection

```sql
-- تشخیص سنسورهایی با بیشترین ناهنجاری
SELECT 
    sensor_id,
    location,
    COUNT(*) as total_anomalies,
    AVG(temperature) as avg_temp
FROM nessie.raw_sensor_data
WHERE anomaly_detected = true
AND timestamp >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY sensor_id, location
ORDER BY total_anomalies DESC;
```

### تحلیل Correlation

```sql
-- همبستگی بین ارتعاش و فشار
SELECT 
    location,
    equipment_type,
    CORR(vibration, pressure) as correlation
FROM nessie.raw_sensor_data
WHERE timestamp >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY location, equipment_type
HAVING COUNT(*) > 100;
```

### Performance Monitoring

```sql
-- بررسی کیفیت داده در ساعات مختلف
SELECT 
    EXTRACT(HOUR FROM timestamp) as hour_of_day,
    AVG(CASE WHEN overall_quality = 'GOOD' THEN 1.0 ELSE 0.0 END) * 100 as quality_pct,
    COUNT(*) as total_readings
FROM nessie.raw_sensor_data
WHERE timestamp >= CURRENT_DATE - INTERVAL '1' DAY
GROUP BY EXTRACT(HOUR FROM timestamp)
ORDER BY hour_of_day;
```

## 🤝 مشارکت در پروژه

### گزارش باگ

لطفاً برای گزارش باگ‌ها اطلاعات زیر را ارائه دهید:

- نسخه سیستم‌عامل
- نسخه Docker و Python
- لاگ‌های خطا
- مراحل بازتولید مشکل

### پیشنهاد بهبودی

برای پیشنهاد ویژگی‌های جدید:

1. مسئله موجود را شرح دهید
2. راه‌حل پیشنهادی را توضیح دهید
3. مثال‌های کاربردی ارائه دهید

## 📚 منابع اضافی

### مستندات کامپوننت‌ها

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [Dremio Documentation](https://docs.dremio.com/)
- [Apache Superset Documentation](https://superset.apache.org/)

### آموزش‌های مفیدی

- [Kafka Streams Tutorial](https://kafka.apache.org/28/documentation/streams/)
- [Spark Structured Streaming Guide](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [Iceberg Table Format](https://iceberg.apache.org/docs/latest/spark-getting-started/)

## 📞 پشتیبانی

برای پشتیبانی و سوالات:

- 📧 Email: support@yourcompany.com
- 💬 Slack: #lakehouse-support
- 📖 Wiki: [Internal Documentation](link-to-wiki)

## 📝 لایسنس

این پروژه تحت لایسنس MIT منتشر شده است. برای جزئیات بیشتر فایل [LICENSE](LICENSE) را مطالعه کنید.

---

**نکته**: این پروژه برای اهداف آموزشی و نمونه‌سازی طراحی شده است. برای استفاده در محیط production، تنظیمات امنیتی و عملکردی اضافی مورد نیاز است.