FROM bitnami/spark:3.4.1

USER root

# install OS tools
RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install kafka-python pandas numpy

# Copy Iceberg and other JARs
RUN wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.4_2.12/1.4.2/iceberg-spark-runtime-3.4_2.12-1.4.2.jar \
    -P /opt/bitnami/spark/jars/

RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar \
    -P /opt/bitnami/spark/jars/

RUN wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar \
    -P /opt/bitnami/spark/jars/

USER 1001
