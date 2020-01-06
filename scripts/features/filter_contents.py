# -*- coding: utf-8 -*-
"""
Get citations content only for certain set of titles which were based on argument file.
"""

from pyspark.sql import Row
from pyspark import SparkContext, SQLContext

INPUT_DATA = 'hdfs://<path-to-file-containing-content-for-wikipedia>'
TITLES_DATA = 'hdfs://<path-to-file-containing-all-unique-titles>'
OUTPUT_DATA = 'hdfs://<output-file-path>/filtered_citations_content.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)
citations_content = sqlContext.read.parquet(INPUT_DATA)
titles = sqlContext.read.parquet(TITLES_DATA)

# Join and get only the titles which are present in the dataset
filtered = citations_content.join(titles, citations_content.page_title == titles.titles)

# Select only titles and content and not id and the duplicated column
filtered = filtered.select('page_title', 'content')
filtered.write.mode('overwrite').parquet(OUTPUT_DATA)

