
from pyspark.sql.functions import col
from pyspark import SparkContext, SQLContext


INPUT_BASE_FEATURES = 'hdfs:///user/harshdee/base_features.parquet'
WIKI_CITATIONS = 'hdfs:///user/harshdee/citations_content.parquet'
DATASET_CITATIONS  = 'hdfs:///user/harshdee/ids_and_citations.parquet'
CITATIONS_FEATURES = 'hdfs:///user/harshdee/citations_features.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')
# Get the citations first since this is where we get the id from
## citations = sqlContext.read.parquet(WIKI_CITATIONS)
## citations = citations.select('id', 'page_title').distinct()
## citations = citations.withColumnRenamed('page_title', 'title')

base_features = sqlContext.read.parquet(INPUT_BASE_FEATURES)
dataset_citations = sqlContext.read.parquet(DATASET_CITATIONS)
## base_features = base_features.join(
##    citations.drop('id'), citations.title == base_features.page_title, how='inner'
##)
## base_features = base_features.drop('title')

base_features = base_features.select(
    'page_title',
    'ID_list',
    'type_of_citation',
    'sections',
    col('id').alias('page_id'),
    col('citations_features._1').alias('retrieved_citation'),
    col('citations_features._2').alias('ref_index'),
    col('citations_features._3').alias('total_words'),
    col('citations_features._4._1').alias('neighboring_words'),
    col('citations_features._4._2').alias('neighboring_tags')
)

filtered = dataset_citations.join(
    base_features,
    (base_features.page_id == dataset_citations.id) &
        (base_features.retrieved_citation == dataset_citations.citations),
    how='inner'
)

# Drop the column since there are 2 columns with citations
filtered = filtered.drop('retrieved_citation')
# filtered.write.mode('overwrite').format('com.databricks.spark.csv').save(CITATIONS_FEATURES)
filtered.write.mode('overwrite').parquet(CITATIONS_FEATURES)



