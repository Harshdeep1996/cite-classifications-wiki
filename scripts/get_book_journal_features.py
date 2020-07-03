import re
import json
import glob
import numpy as np
import pandas as pd
from tqdm import tqdm
from itertools import chain

tqdm.pandas()

print('Reading the data')
citations_features = pd.read_parquet('/dlabdata1/harshdee/citations_features.parquet/', engine='pyarrow')
print('Data is read from parquet file')
print('the columns in the citations features are: {}'.format(citations_features.columns))

citation_with_ids = citations_features[citations_features['ID_list'].notnull()]
print('Total citations with NOT-NULL ID LIST: {}'.format(len(citation_with_ids)))
# Formulate a structure for the ID_List in which we can do something meaningful
citation_with_ids['ID_list'] = citation_with_ids['ID_list'].progress_apply(
    lambda x: list(item.split('=') for item in x.replace('{','').replace('}','').replace(' ', '').split(','))
)

# Get the kinds of ids associated with each tuple
kinds_of_ids = set()
def update_ids(x):
    for item in x:
        kinds_of_ids.add(item[0])

_ = citation_with_ids['ID_list'].progress_apply(lambda x: update_ids(x))

# Add the columns with NoneType in the previous DF
for id_ in kinds_of_ids:
    citation_with_ids[id_] = None

print('Total kind of Citation IDs: {}'.format(len(kinds_of_ids)))

# Set the value of identifiers for each column, for e.g. DOI, ISBN etc.
def set_citation_val(x):
    for item in x['ID_list']:
        citation_with_ids.at[x.name, item[0]] = item[1] if len(item) >= 2 else None

_ = citation_with_ids.progress_apply(lambda x: set_citation_val(x), axis=1)

#####             ######
## Setting the labels ##
#####             ######

citation_with_ids['actual_label'] = 'rest'
citation_with_ids.loc[~pd.isna(citation_with_ids['PMC']), ['actual_label']] = 'journal'
citation_with_ids.loc[~pd.isna(citation_with_ids['PMID']), ['actual_label']] = 'journal'
only_doi = (
    ~pd.isna(citation_with_ids['DOI']) &
    pd.isna(citation_with_ids['PMC']) &
    pd.isna(citation_with_ids['PMID']) &
    pd.isna(citation_with_ids['ISBN'])
)
citation_with_ids.loc[only_doi, ['actual_label']] = 'journal'

only_book = (
    ~pd.isna(citation_with_ids['ISBN']) &
    pd.isna(citation_with_ids['PMC']) &
    pd.isna(citation_with_ids['PMID']) &
    pd.isna(citation_with_ids['DOI'])
)
citation_with_ids.loc[only_book, ['actual_label']] = 'book'

both_book_and_doi_journal = (
    ~pd.isna(citation_with_ids['ISBN']) &
    ~pd.isna(citation_with_ids['DOI']) &
    pd.isna(citation_with_ids['PMID']) &
    pd.isna(citation_with_ids['PMC']) &
    citation_with_ids['type_of_citation'].isin(['cite journal', 'cite conference'])
)
citation_with_ids.loc[both_book_and_doi_journal, ['actual_label']] = 'journal'

both_book_and_doi_book = (
    ~pd.isna(citation_with_ids['ISBN']) &
    ~pd.isna(citation_with_ids['DOI']) &
    pd.isna(citation_with_ids['PMID']) &
    pd.isna(citation_with_ids['PMC']) &
    citation_with_ids['type_of_citation'].isin(['cite book', 'cite encyclopedia'])
)
citation_with_ids.loc[both_book_and_doi_book, ['actual_label']] = 'book'

## Made the dataset which contains citations book and journal labeled
citation_with_ids = citation_with_ids[citation_with_ids['actual_label'].isin(['book', 'journal'])]
citation_with_ids = citation_with_ids[[
    'type_of_citation', 'citations', 'id', 'ref_index', 'sections',
     'total_words', 'neighboring_tags', 'actual_label', 'neighboring_words'
]]
print('The total number of citations_with_ids: {}'.format(citation_with_ids.shape))

citation_with_ids = citation_with_ids.set_index(['id', 'citations'])
citation_with_ids = citation_with_ids[~citation_with_ids.index.duplicated(keep='first')]
citation_with_ids = citation_with_ids.reset_index()

print('IDs for book and journal which fulfil the criteria: {}'.format(citation_with_ids.shape[0]))

######################################
## Removing the biases ##
#####################################

citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('doi\s{0,10}=\s{0,10}([^|]+)', 'doi = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('isbn\s{0,10}=\s{0,10}([^|]+)', 'isbn = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('pmc\s{0,10}=\s{0,10}([^|]+)', 'pmc = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('pmid\s{0,10}=\s{0,10}([^|]+)', 'pmid = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('url\s{0,10}=\s{0,10}([^|]+)', 'url = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('work\s{0,10}=\s{0,10}([^|]+)', 'work = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('newspaper\s{0,10}=\s{0,10}([^|]+)', 'newspaper = ', x))
citation_with_ids['citations'] = citation_with_ids['citations'].progress_apply(
    lambda x: re.sub('website\s{0,10}=\s{0,10}([^|]+)', 'website = ', x))

citation_with_ids['actual_label'].value_counts()
citation_with_ids['actual_prob'] = citation_with_ids['actual_label'].progress_apply(lambda x: 0.45 if x == 'book' else 0.55)

book_journal_features = citation_with_ids.sample(n=1700000, weights='actual_prob')

print(book_journal_features['actual_label'].value_counts())
## Save the file
book_journal_features.to_parquet('/dlabdata1/harshdee/book_journal_features.parquet')

