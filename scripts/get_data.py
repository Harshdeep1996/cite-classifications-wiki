# -*- coding: utf-8 -*-
## STEP 1: Get the citations for each article from the wikicode data ##

from pyspark.sql import Row
from helpers import get_citations
from pyspark import SparkContext, SQLContext
from pyspark.sql.functions import explode, col


INPUT_DATA = 'hdfs:///user/piccardi/enwiki-20181001-pages-articles-multistream.xml.bz2'
OUTPUT_DATA = 'hdfs:///user/harshdee/citations.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')

wiki = sqlContext.read.format('com.databricks.spark.xml').options(rowTag='page').load(INPUT_DATA)
pages = wiki.where('ns = 0').where('redirect is null')

# Get only ID, title, revision text's value which we are interested in
pages = pages['id', 'title', 'revision.text.#VALUE', 'revision.id', 'revision.parentid']
pages = pages.toDF('id', 'title', 'content', 'r_id', 'r_parentid')

def get_as_row(line):
    """
    Get each article's citations with their id and title.

    :line: the wikicode for the article.
    """
    return Row(
        citations=get_citations(line.content), id=line.id,
        title=line.title, r_id=line.r_id, r_parentid=line.r_parentid
    )

cite_df = sqlContext.createDataFrame(pages.map(get_as_row))
cite_df = cite_df.withColumn('citations', explode('citations'))
cite_df.write.mode('overwrite').parquet(OUTPUT_DATA)
