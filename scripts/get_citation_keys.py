from pyspark import SparkContext, SQLContext
from pyspark.sql import Row
from pyspark.sql.types import ArrayType, StringType
from pyspark.sql.functions import udf, lit, col

OUTPUT_DATA = 'hdfs:///user/harshdee/citations_separated.parquet'

sc = SparkContext()
sqlContext = SQLContext(sc)

generic_citations = sqlContext.read.parquet('hdfs:///user/harshdee/generic_citations.parquet/')

udf_get_keys = udf(lambda x: x.keys() if x.keys() is not None else [], ArrayType(StringType()))
# Get all the keys in the citation dict and remove that additional column from the additional DF
generic_citations = generic_citations.withColumn('citation_keys', udf_get_keys(generic_citations.citation_dict))
generic_citations.registerTempTable('generic_citations')

citation_keys = sqlContext.sql('select citation_keys as keys from generic_citations')

# Get all the keys present in the Map for the citation template
distinct_keys = set()
for line in citation_keys.rdd.toLocalIterator():
    distinct_keys.update(line.keys)
distinct_keys = list(distinct_keys)


for key_ in distinct_keys:
    generic_citations = generic_citations.withColumn(key_, lit(None).cast(StringType()))

def get_value_from_citation(citation):
    """
    Get value for each key for citation.
    """
    results = []
    for key_ in distinct_keys:
       if key_ not in citation:
           results.append(None)
       else:
           results.append(citation[key_])
    return results

def get_as_row(line):
    """
    Get each article's generic temolated citations with their id, title and type.

    :line: a row from the dataframe generated from get_data.py.
    """
    (city, title, issue, p_name, degree, format_, volume, authors,
    date, pages, chron, chapter, url, p_place, id_list, encyclopedia,
    series_number, access_date, series, edition, periodical, title_type) = get_value_from_citation(line.citation_dict)
    return Row(
        citations=line.citations, id=line.id, type_of_citation=line.type_of_citation, page_title=line.page_title,
        r_id=line.r_id, r_parentid=line.r_parentid, Chapter=chapter, PublisherName=p_name, Format=format_,
        Degree=degree, Title=title, URL=url, Series=series, Authors=authors, ID_list=id_list, Encyclopedia=encyclopedia,
        Periodical=periodical, PublicationPlace=p_place, Date=date, Edition=edition, Pages=pages, Chron=chron, City=city,
        Issue=issue, Volume=volume, SeriesNumber=series_number, AccessDate=access_date, TitleType=title_type, sections=line.sections
    )

generic_citations = sqlContext.createDataFrame(generic_citations.rdd.map(get_as_row), samplingRatio=0.2)
generic_citations.write.mode('overwrite').parquet(OUTPUT_DATA)

# Code to get CSV file for some particular column which only have ID List
# id_list_exists = generic_citations.where(col('ID_list').isNotNull())
# id_list_exists.select(
#     'id', 'title_of_page',
#     'title_of_citation', 'ID_list', 'Authors'
# ).write.format('com.databricks.spark.csv').save('citations_ids.csv')
