# -*- coding: utf-8 -*-
## STEP 1: Get the citations for each article from the wikicode data ##

from pyspark.sql import Row
from helpers import get_citations
from pyspark import SparkContext, SQLContext
from pyspark.sql.functions import explode, col, split, trim, lower, regexp_replace, substring, length, expr


INPUT_DATA = 'hdfs:///user/piccardi/enwiki-20181001-pages-articles-multistream.xml.bz2'
OUTPUT_DATA = 'hdfs:///user/harshdee/citations.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')

wiki = sqlContext.read.format('com.databricks.spark.xml').options(rowTag='page').load(INPUT_DATA)
pages = wiki.where('ns = 0').where('redirect is null')

# Get only ID, title, revision text's value which we are interested in
pages = pages['id', 'title', 'revision.text.#VALUE', 'revision.id', 'revision.parentid']
pages = pages.toDF('id_', 'page_title', 'content', 'r_id', 'r_parentid').cache()

def get_as_row(line):
    """
    Get each article's citations with their id and title.

    :line: the wikicode for the article.
    """
    return Row(
        results=get_citations(line.content), id_=line.id_,
        page_title=line.page_title, r_id=line.r_id, r_parentid=line.r_parentid
    )

cite_df = sqlContext.createDataFrame(pages.map(get_as_row))
cite_df = cite_df.withColumn('results', explode('results'))
cite_df = cite_df.select(
    'id_', 'page_title', 'r_id', 'r_parentid',
    col('results')[0].alias('citation'), col('results')[1].alias('section'), col('results')[2].alias('all_words')
)
split_col = split(cite_df['citation'], '\|')
cite_df = cite_df.withColumn('type_of_citation', lower(trim(split_col.getItem(0))))
cite_df = cite_df.withColumn('type_of_citation', regexp_replace('type_of_citation', '\{\{', ''))
cite_df = cite_df.withColumn('type_of_citation', expr('substring(type_of_citation, 3, length(type_of_citation))'))
cite_df.write.mode('overwrite').parquet(OUTPUT_DATA)
