# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze Layer - Raw Data Ingestion
# MAGIC 
# MAGIC This notebook ingests raw data from Azure Blob Storage and writes it to Delta Lake Bronze layer.
# MAGIC 
# MAGIC **Bronze Layer Characteristics:**
# MAGIC - Raw data, exactly as received
# MAGIC - Minimal transformation (schema enforcement)
# MAGIC - Append-only writes
# MAGIC - Audit columns added (ingestion timestamp, source file)

# COMMAND ----------

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, input_file_name, lit
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, DateType
from delta.tables import DeltaTable

# COMMAND ----------

# MAGIC %md
# MAGIC ## Configuration

# COMMAND ----------

# Storage account configuration
storage_account_name = dbutils.widgets.get("storage_account_name")
container_name = "raw-data"
bronze_container = "bronze-data"

# Mount storage if not already mounted
storage_account_key = dbutils.secrets.get(scope="etl-secrets", key="storage-connection-string").split("AccountKey=")[1].split(";")[0]

spark.conf.set(
    f"fs.azure.account.key.{storage_account_name}.dfs.core.windows.net",
    storage_account_key
)

# Paths
raw_data_path = f"abfss://{container_name}@{storage_account_name}.dfs.core.windows.net/"
bronze_path = f"abfss://{bronze_container}@{storage_account_name}.dfs.core.windows.net/employees"

# COMMAND ----------

# MAGIC %md
# MAGIC ## Define Schema

# COMMAND ----------

# Define explicit schema for data quality
employee_schema = StructType([
    StructField("EmployeeID", IntegerType(), False),
    StructField("FirstName", StringType(), True),
    StructField("LastName", StringType(), True),
    StructField("Department", StringType(), True),
    StructField("Salary", DoubleType(), True),
    StructField("HireDate", DateType(), True)
])

# COMMAND ----------

# MAGIC %md
# MAGIC ## Ingest Raw Data

# COMMAND ----------

# Read raw CSV files
df_raw = (
    spark.read
    .format("csv")
    .option("header", "true")
    .option("inferSchema", "false")
    .schema(employee_schema)
    .load(f"{raw_data_path}/*.csv")
)

# Add audit columns
df_bronze = (
    df_raw
    .withColumn("ingestion_timestamp", current_timestamp())
    .withColumn("source_file", input_file_name())
    .withColumn("bronze_layer_version", lit("1.0"))
)

print(f"Rows to ingest: {df_bronze.count()}")
df_bronze.printSchema()
display(df_bronze.limit(10))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to Bronze Delta Table

# COMMAND ----------

# Write to Delta Lake with merge schema enabled
(
    df_bronze.write
    .format("delta")
    .mode("append")
    .option("mergeSchema", "true")
    .save(bronze_path)
)

print(f"✅ Data written to Bronze layer: {bronze_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verify Bronze Table

# COMMAND ----------

# Read back and verify
df_verify = spark.read.format("delta").load(bronze_path)
print(f"Total rows in Bronze table: {df_verify.count()}")
display(df_verify.orderBy("ingestion_timestamp", ascending=False).limit(20))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Checks

# COMMAND ----------

from pyspark.sql.functions import col, count, when, isnan

# Check for nulls
null_counts = df_verify.select([
    count(when(col(c).isNull(), c)).alias(c) 
    for c in df_verify.columns
])
display(null_counts)

# Check for duplicates
duplicate_count = df_verify.groupBy("EmployeeID").count().filter("count > 1").count()
print(f"Duplicate EmployeeIDs: {duplicate_count}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Optimize Delta Table

# COMMAND ----------

# Optimize for better query performance
spark.sql(f"OPTIMIZE delta.`{bronze_path}`")
print("✅ Delta table optimized")

# Vacuum old files (careful in production!)
# spark.sql(f"VACUUM delta.`{bronze_path}` RETAIN 168 HOURS")
