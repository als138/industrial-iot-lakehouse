# Industrial IoT Lakehouse

A sample repository demonstrating how to build an Industrial Internet of Things (IoT) Lakehouse architecture using open-source tools like Kafka, Spark, MinIO, Apache Iceberg, Nessie, Dremio, and Superset for end-to-end IoT data processing and analytics.

---

##  Overview

This project showcases a self-contained, modular pipeline to ingest, store, transform, query, and visualize IoT data:

- **Kafka** for real-time streaming ingestion.
- **MinIO** as a low-cost, S3-compatible object storage layer.
- **Apache Spark** for ETL and data transformation.
- **Apache Iceberg** + **Nessie** for managing versioned, transactional data lakes.
- **Dremio** for SQL querying and data virtualization.
- **Superset** for interactive dashboarding and visualization.

---

##  Repository Structure

- `configs/` — Configuration files for services (e.g., MinIO, Kafka, Nessie).
- `data/` — Sample data files or datasets used for ingestion and testing Available in (https://www.kaggle.com/datasets/ziya07/industrial-iot-fault-detection-dataset).
- `kafka/` — Scripts related to topic setup and data producers/consumers.
- `spark/` — Spark jobs to process and transform raw IoT data.
- `docs/` — Documentation, diagrams, architectural overview.
- `docker-compose.yml` — Main orchestration for spinning up all services.
- `docker-compose-nessie-update.yml` — Optional configuration for Nessie updates.
- `.sh` scripts:
  - `setup-minio-folders.sh`
  - `setup-iceberg.sh`
  - `setup-nessie-complete.sh`
  - `run-complete-pipeline.sh`
  - `fix-dremio-warehouse.sh`
  - `fix-superset-dremio-datetime.sh`
- `dremio.sql` — SQL commands or schema definitions for Dremio.
- `guid.txt` — Likely a globally unique identifier or version tag reference.

---

##  Getting Started

### Prerequisites

Things you'll need:

- Docker and Docker Compose installed
- Java (for running Kafka or Spark jobs, if needed)
- Python (if any of the Spark jobs or utilities are Python-based)

### Setup Steps

1. **Launch all services**

   ```bash
   docker-compose up -d
   
2. **Initialize storage layers**
   ```bash
   ./setup-minio-folders.sh
    ./setup-iceberg.sh
    ./setup-nessie-complete.sh

3. **Run full  pipeline**
   ```bash
    ./run-complete-pipeline.sh
4. **Straming & Producing**
  
   *Terminal 1 :*
  
   ```bash
              docker exec -it spark-master spark-submit \
              --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.4.1,org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.5.0 \
              --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
              --conf spark.sql.catalog.nessie=org.apache.iceberg.spark.SparkCatalog \
              --conf spark.sql.catalog.nessie.catalog-impl=org.apache.iceberg.nessie.NessieCatalog \
                /opt/spark/work-dir/iceberg-streaming-processor.py
    ```
   *Terminal 2:*
  
   ```bash
           docker exec -it spark-master python /opt/spark/work-dir/data-producer.py
    ```
          
5. **Query data using Dremio**

      Apply dremio.sql or run your own SQL via the Dremio UI.

6. **Visualize insights with Superset**

      Open Superset in your browser, connect to Dremio, and build dashboards.
      | Component | Purpose                                          |
| --------- | ------------------------------------------------ |
| Kafka     | Real-time ingestion of IoT data                  |
| MinIO     | S3-compatible storage for raw and processed data |
| Spark     | ETL and transformation engine                    |
| Iceberg   | Versioned, transactional data lake storage       |
| Nessie    | Git-like version control for Iceberg metadata    |
| Dremio    | SQL-based querying & data virtualization         |
| Superset  | Dashboarding and visualization layer             |

## Superset Results

  ![iot-dashboard-2025-08-04T13-32-34 080Z](https://github.com/user-attachments/assets/9803957f-1fbd-41e5-b972-50e9ad9bcf37)



## Usage Scenario

  -Simulation: Run the full pipeline locally for experimentation.

  -Extension: Replace sample data with real sensor input; deploy on cluster/cloud.

  -Versioning: Utilize Iceberg + Nessie to track data changes and schema evolution.

  -Visualization: Build real-time dashboards reflecting IoT device performance.

## Contributing

  -Contributions are welcome! Whether you're:

  -Adding sample datasets,

  -Offering robust production-ready configuration files,

  -Enhancing dashboards or analytics,

