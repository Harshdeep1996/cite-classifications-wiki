# -*- coding: utf-8 -*-
## STEP 1: Get the citations for each article from the wikicode data ##

import regex
from bs4 import BeautifulSoup
from pyspark.sql import Row
from StringIO import StringIO
from pyspark import SparkContext, SQLContext
from pyspark.sql.functions import explode, col

INPUT_DATA = 'hdfs:///user/piccardi/enwiki-20181001-pages-articles-multistream.xml.bz2'
OUTPUT_DATA = 'hdfs:///user/harshdee/citations.parquet'

CITATION_REGEX = (
    '{{ci[\w\s]*[^}]*}}(?:}}(?R)?)?|{{Ci[\w\s]*[^}]*}}(?:}}(?R)?)?|{{h[\w\s]*[^}]*}}(?:}}(?R)?)?|{{H[\w\s]*[^}]*}}(?:}}(?R)?)?'
)

sc = SparkContext()
sqlContext = SQLContext(sc)
sqlContext.setConf('spark.sql.parquet.compression.codec', 'snappy')

wiki = sqlContext.read.format('com.databricks.spark.xml').options(rowTag='page').load(INPUT_DATA)
pages = wiki.where('ns = 0').where('redirect is null')

# Get only ID, title, revision text's value which we are interested in
pages = pages['id', 'title', 'revision.text.#VALUE']
pages = pages.withColumnRenamed('#VALUE', 'content')

def get_citations(page_content):
    """
    Get the <ref></ref> tag citations and citations which are standalone in a format, for e.g. "* {{"

    :param: page_content: <text></text> part of the wikicode xml.
    """
    citations = dict()
    refs_in_line = []
    buf = StringIO(page_content)
    current_section = 'Initial Section'

    for line in buf.readlines():
        if line.startswith('== '):
            current_section = line.strip()
        elif line.startswith('* {{'):
            refs_in_line = regex.findall(CITATION_REGEX, line)
        else:
            refs_in_line = [r.text for r in BeautifulSoup(line).findAll('ref') if r.text]

        if not refs_in_line:
            continue

        for ref in refs_in_line:
            potential_citation = regex.findall(CITATION_REGEX, ref)
            if not potential_citation:
                continue

            # Append section in which the citation was present
            for c in potential_citation:
                citations.setdefault(c, [])
                if current_section not in citations[c]:
                    citations[c].append(current_section)

    return citations.items()

def get_as_row(line):
    """
    Get each article's citations with their id and title.

    :line: the wikicode for the article.
    """
    return Row(citations=get_citations(line.content), id=line.id, title=line.title)

cite_df = sqlContext.createDataFrame(pages.map(get_as_row))
cite_df = cite_df.withColumn('citations', explode('citations'))
cite_df = cite_df.withColumn('citation', col('citations._1')).withColumn('sections', col('citations._2')).drop('citations')
cite_df.write.mode('overwrite').parquet(OUTPUT_DATA)
