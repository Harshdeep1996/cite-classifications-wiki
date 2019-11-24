import tldextract

from pyspark.sql import Row
from pyspark import SparkContext, SQLContext
from pyspark.sql.functions import udf, lit, col
from pyspark.sql.types import ArrayType, StringType


INPUT_DATA = 'hdfs:///user/harshdee/citations_separated.parquet'
OUTPUT_DATA = 'hdfs:///user/harshdee/selected_newspapers_citations.parquet/'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')
citations_separated = sqlContext.read.parquet(INPUT_DATA)

citations_separated = citations_separated.where(col("URL").isNotNull())

def get_top_domain(citation_url):
    ext = tldextract.extract(citation_url)
    return ext.domain

topdomain_udf = udf(get_top_domain)
citations_separated = citations_separated.withColumn('tld', topdomain_udf('URL'))

NEWSPAPERS = {'nytimes', 'bbc', 'washingtonpost', 'cnn', 'theguardian', 'huffingtonpost', 'indiatimes'}

citations_separated = citations_separated.where(col("tld").isin(NEWSPAPERS))
citations_separated.write.mode('overwrite').parquet(OUTPUT_DATA)
