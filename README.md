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
- `data/` — Sample data files or datasets used for ingestion and testing.
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



