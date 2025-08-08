
FROM bitnami/spark:3.4.1

USER root

# Install OS tools
RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install \
    kafka-python \
    pandas \
    numpy \
    pyiceberg \
    boto3

# Download and install Iceberg & AWS JARs into Spark’s classpath
RUN wget -q \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/1.4.3/iceberg-aws-bundle-1.4.3.jar \
    -P /opt/bitnami/spark/jars/ && \
    wget -q \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.4.3/iceberg-spark-runtime-3.5_2.12-1.4.3.jar \
    -P /opt/bitnami/spark/jars/ && \
    wget -q \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar \
    -P /opt/bitnami/spark/jars/ && \
    wget -q \
     https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar \
    -P /opt/bitnami/spark/jars/

# Revert to non-root user for running Spark
USER 1001
