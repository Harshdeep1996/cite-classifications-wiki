# -*- coding: utf-8 -*-
## STEP 1: Get the citations for each article from the wikicode data ##

from nltk import pos_tag
from pyspark.sql import Row
from helpers import get_citations
from pyspark import SparkContext, SQLContext
from pyspark.sql.types import ArrayType, StructField, StringType, StructType, IntegerType
from pyspark.sql.functions import explode, col, split, trim, lower, regexp_replace, substring, length, expr, udf, struct


INPUT_DATA = 'hdfs:///user/piccardi/enwiki-20181001-pages-articles-multistream.xml.bz2'
OUTPUT_DATA = 'hdfs:///user/harshdee/citations.parquet'
TOTAL_NEIGHBORING_WORDS = 20

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
cite_df = cite_df.withColumn('all_words', udf(lambda x: [i[2:len(i)-1] for i in x], ArrayType(StringType()))('all_words')).cache()

## Citations with features ##

# Feature 1: Total Words
cite_df = cite_df.withColumn('total_words_', udf(lambda x: len(x), IntegerType())('all_words'))

# Feature 2: Where is the citation located by index?
get_ref_index = udf(lambda x: x[1].index(x[0]), IntegerType())
cite_df = cite_df.withColumn('ref_index', get_ref_index(struct('citation', 'all_words')))

# Feature 3: Neighboring words before the citation
get_neighboring_words = udf(
    lambda x: x[1][:x[0]] 
    if x[0] < TOTAL_NEIGHBORING_WORDS else x[1][x[0]:TOTAL_NEIGHBORING_WORDS - x[0]],
    ArrayType(StringType())
)
cite_df = cite_df.withColumn('neighboring_words', get_ref_index(struct('ref_index', 'all_words')))

# Feature 4: POS tags for the citation

def generate_tags(neighboring_before_words):
    # Get part of speech tags for the neigbhoring words for the citation
    tags = [t for _, t in pos_tag(neighboring_before_words)]
    # Get all tags which 'might' be wikipedia citation
    index_of_citations = [i for i, word in enumerate(neighboring_before_words) if word.startswith('{{')]
    # Change tags of citations to 'Wikicode' -  so that it can be treated as a feature
    for index in index_of_citations:
        tags[index] = 'WIKICODE'
    return tags

get_pos_tags = udf(lambda x: generate_tags(x), ArrayType(StringType()))
cite_df = cite_df.withColumn('tags', get_ref_index('neighboring_words')))

# Drop the all_words column which is redundant in nature
cite_df = cite_df.drop('all_words')

cite_df.write.mode('overwrite').parquet(OUTPUT_DATA)
