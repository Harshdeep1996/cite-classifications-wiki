
from pyspark.sql import Row
from pyspark import SparkContext, SQLContext
from pyspark.sql.functions import udf, lit, col
from pyspark.sql.types import ArrayType, StringType


FEATURES_DATA = 'hdfs:///user/harshdee/base_features_complete.parquet'
SELECTED_ENTERTAINMENT = 'hdfs:///user/harshdee/entertainment_citations.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')
features = sqlContext.read.parquet(FEATURES_DATA)
features = features.withColumnRenamed('page_title', 'page_title_')

features = features.select(
    col('citations_features._1').alias('retrieved_citation'),
    col('citations_features._2').alias('ref_index'),
    col('citations_features._3').alias('total_words'),
    col('citations_features._4._1').alias('neighboring_words'),
    col('citations_features._4._2').alias('neighboring_tags')
)

selected_entertainment = sqlContext.read.parquet(SELECTED_ENTERTAINMENT)

## def array_to_string(my_list):
##    return '[' + ','.join([str(elem) for elem in my_list]) + ']'
## array_to_string_udf = udf(array_to_string,StringType())

results = features.join(selected_entertainment, features['retrieved_citation'] == selected_entertainment['citations'])
## results = results.withColumn('neighboring_words', array_to_string_udf(results["neighboring_words"]))
## results = results.withColumn('neighboring_tags', array_to_string_udf(results["neighboring_tags"]))

results = results.drop('retrieved_citation')
results.write.mode('overwrite').parquet('hdfs:///user/harshdee/entertainment_citations_features.parquet')
## results.write.format('com.databricks.spark.csv').option('delimiter', '\t').save('entertainment_citations_features.csv')

