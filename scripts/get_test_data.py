# -*- encoding: utf-8 -*-

from pyspark import SparkContext, SQLContext

INPUT_DATA = 'hdfs:///user/piccardi/enwiki-20181001-pages-articles-multistream.xml.bz2'

sc = SparkContext()
sqlContext = SQLContext(sc)

wiki = sqlContext.read.format('com.databricks.spark.xml').options(rowTag='page').load(INPUT_DATA)
pages = wiki.where('ns = 0').where('redirect is null')

# Get only ID, title, revision text's value which we are interested in
pages = pages['id', 'title', 'revision.text.#VALUE', 'revision.id', 'revision.parentid']
pages = pages.toDF('id', 'title', 'content', 'r_id', 'r_parentid')

random_pages = sqlContext.createDataFrame(pages.rdd.takeSample(False, 5, seed=0))
random_pages.write.format('com.databricks.spark.csv').save('random_pages.csv')
