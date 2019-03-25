# -*- encoding: utf-8 -*-

import mwparserfromhell
from pyspark.sql import Row
from const import CITATION_TEMPLATES
from helpers import check_if_balanced
from pyspark import SparkContext, SQLContext
from wikiciteparser.parser import parse_citation_template
from pyspark.sql.functions import split, regexp_replace, trim, lower, explode, col


INPUT_DATA = 'hdfs:///user/harshdee/citations.parquet'
OUTPUT_DATA = 'hdfs:///user/harshdee/generic_citations.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)

citations = sqlContext.read.parquet(INPUT_DATA)

split_col = split(citations['citation'], '\|') 
citations = citations.withColumn('type_of_citation', lower(trim(split_col.getItem(0))))
citations = citations.withColumn('type_of_citation', regexp_replace('type_of_citation', '\{\{', ''))

citations = citations.filter(citations['type_of_citation'].isin(CITATION_TEMPLATES))


def get_generic_template(citation):
    """
    Get generic template of a citation using the wikiciteparser library.

    :param: citation according to a particular format as described in const.py
    """
    not_parseable = {'Title': 'Citation generic template not possible'}
    if not check_if_balanced(citation):
        citation = citation + '}}'
    wikicode_tpl = mwparserfromhell.parse(citation)

    try:
        template = wikicode_tpl.filter_templates()[0]
    except IndexError:
        return not_parseable
    
    parsed_result = parse_citation_template(template)
    return parsed_result if parsed_result is not None else not_parseable


def get_as_row(line):
    """
    Get each article's generic temolated citations with their id, title and type.

    :line: a row from the dataframe generated from get_data.py.
    """
    return Row(
        citation=get_generic_template(line.citation), id=line.id,
        title=line.title, sections=line.sections, type_of_citation=line.type_of_citation
    )

generic_citations = sqlContext.createDataFrame(citations.map(get_as_row))
generic_citations.write.mode('overwrite').parquet(OUTPUT_DATA)
