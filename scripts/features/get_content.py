from pyspark.sql import Row
from pyspark import SparkContext, SQLContext

INPUT_DATA = 'hdfs:///user/harshdee/enwiki-latest-pages-articles-multistream.xml.bz2'
OUTPUT_DATA = 'hdfs:///user/harshdee/citations_content.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')

wiki = sqlContext.read.format('com.databricks.spark.xml').options(rowTag='page').load(INPUT_DATA)
pages = wiki.where('ns = 0').where('redirect is null')

# Get only ID, title, revision text's value which we are interested in
pages = pages['id', 'title', 'revision.text']
pages = pages.toDF('id', 'page_title', 'content')

## citations_with_words = sqlContext.createDataFrame(pages.map(get_as_row))
pages.write.mode('overwrite').parquet(OUTPUT_DATA)
## citations_with_words.write.format('com.databricks.spark.csv').save('citations_words.csv')
