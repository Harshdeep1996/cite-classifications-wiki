from pyspark.sql.types import *
from pyspark.sql import Row
from helpers import get_citations
from pyspark import SparkContext, SQLContext
from pyspark.sql.functions import explode, col, split, trim, udf, lower, regexp_replace


INPUT_DATA = 'hdfs:///user/harshdee/enwiki-latest-pages-articles-multistream.xml.bz2'
OUTPUT_DATA = 'hdfs:///user/harshdee/citations.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')

wiki = sqlContext.read.format('com.databricks.spark.xml').options(rowTag='page').load(INPUT_DATA)
pages = wiki.where('ns = 0').where('redirect is null')

# Get only ID, title, revision text's value which we are interested in
pages = pages['id', 'title', 'revision.text', 'revision.id', 'revision.parentid']
pages = pages.toDF('id', 'title', 'content', 'r_id', 'r_parentid')

def get_as_row(line):
    """
    Get each article's citations with their id and title.
    :line: the wikicode for the article.
    """
    citations = get_citations(line.content)
    return Row(
        citations=citations , id=line.id,
        title=line.title, r_id=line.r_id, r_parentid=line.r_parentid
    )

cite_df = sqlContext.createDataFrame(pages.rdd.map(get_as_row))
cite_df = cite_df.withColumn('citations', explode('citations'))
# cite_df = cite_df.withColumn('tmp', zip_('citations', 'sections')).withColumn('tmp', explode('tmp'))
cite_df = cite_df.select('id', 'r_id', 'r_parentid', 'title', col('citations._1').alias('citations'), col('citations._2').alias('sections'))
split_col = split(cite_df['citations'], '\|')
cite_df = cite_df.withColumn('type_of_citation', lower(trim(split_col.getItem(0))))
cite_df = cite_df.withColumn('type_of_citation', regexp_replace('type_of_citation', '\{\{', ''))
cite_df.write.mode('overwrite').parquet(OUTPUT_DATA)
