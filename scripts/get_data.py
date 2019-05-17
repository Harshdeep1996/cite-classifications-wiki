# -*- coding: utf-8 -*-
## STEP 1: Get the citations for each article from the wikicode data ##

from pyspark.sql import Row
from helpers import get_citations, get_sub_without_unicode
from pyspark import SparkContext, SQLContext
from pyspark.sql.types import ArrayType, StructField, StringType, StructType
from pyspark.sql.functions import explode, col, split, trim, lower, regexp_replace, substring, length, expr, udf


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

schema = ArrayType(StructType([
    StructField('citation', StringType()),
    StructField('section', ArrayType(StringType())),
    StructField('all_words', ArrayType(StringType()))
]))
results_udf = udf(lambda z: get_citations(z), schema)
cite_df = pages.withColumn('content', results_udf(pages.content))
cite_df = cite_df.withColumn('content', explode('content'))
cite_df = cite_df.withColumn('citation', expr('substring(content.citation, 3, length(content.citation))'))
cite_df = cite_df.select(
    'id_', 'page_title', 'r_id', 'r_parentid',
    'citation', col('content.section').alias('section'), col('content.all_words').alias('all_words')
)
split_col = split(cite_df['citation'], '\|')
cite_df = cite_df.withColumn('type_of_citation', lower(trim(split_col.getItem(0))))
cite_df = cite_df.withColumn('type_of_citation', regexp_replace('type_of_citation', '\{\{', ''))
cite_df = cite_df.withColumn('all_words', udf(lambda x: [i[2:len(i)-1] for i in x], ArrayType(StringType()))('all_words'))
cite_df.write.mode('overwrite').parquet(OUTPUT_DATA)
