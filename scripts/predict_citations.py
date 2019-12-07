#!/usr/bin/env python
# coding: utf-8

import os
import gc
import glob
import keras
import numbers
import numpy as np
import pandas as pd
from tqdm import tqdm
import tensorflow as tf
from itertools import chain
from keras.models import Model
from keras.models import load_model

import matplotlib.pyplot as plt
from collections import Counter
from sklearn import preprocessing
from sklearn.manifold import TSNE
from gensim.models import FastText
from sklearn.decomposition import PCA
from keras.callbacks import ReduceLROnPlateau
from sklearn.model_selection import train_test_split
from keras.preprocessing.sequence import pad_sequences
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.feature_extraction.text import CountVectorizer
from keras.layers import Input, Embedding, LSTM, Dense, Bidirectional, Dropout
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score

import warnings
warnings.filterwarnings("ignore")
# Initializing tqdm for pandas
tqdm.pandas()

from tensorflow.python.client import device_lib

local_device_protos = device_lib.list_local_devices()
print([x.name for x in local_device_protos if x.device_type == 'GPU'])


np.random.seed(0)

citations_features = pd.read_parquet('/dlabdata1/harshdee/citations_features.parquet/', engine='pyarrow')
dataset = pd.read_csv('../dataset.csv')

# Merging the citation and their corresponding features which have been extracted
book_journal_features = pd.merge(
    dataset, citations_features, how='inner', left_on=['id','citation'], right_on = ['id','citation']
)
book_journal_features.drop('page_title_y', axis=1, inplace=True)
book_journal_features.drop('Unnamed: 0', axis=1, inplace=True)

print(book_journal_features.shape)

# Only consider unique citations so that the dataset is more varied
book_journal_features = book_journal_features.set_index(['id', 'citation'])
book_journal_features = book_journal_features[~book_journal_features.index.duplicated(keep='first')]
book_journal_features = book_journal_features.reset_index()
book_journal_features['actual_label'] = 'rest'
book_journal_features.loc[~pd.isna(book_journal_features['PMC']), ['actual_label']] = 'journal'
book_journal_features.loc[~pd.isna(book_journal_features['PMID']), ['actual_label']] = 'journal'


only_doi = (
    ~pd.isna(book_journal_features['DOI']) & 
    pd.isna(book_journal_features['PMC']) & 
    pd.isna(book_journal_features['PMID']) &
    pd.isna(book_journal_features['ISBN'])
)
book_journal_features.loc[only_doi, ['actual_label']] = 'journal'

only_book = (
    ~pd.isna(book_journal_features['ISBN']) & 
    pd.isna(book_journal_features['PMC']) & 
    pd.isna(book_journal_features['PMID']) &
    pd.isna(book_journal_features['DOI'])
)
book_journal_features.loc[only_book, ['actual_label']] = 'book'

both_book_and_doi_journal = (
    ~pd.isna(book_journal_features['ISBN']) & 
    ~pd.isna(book_journal_features['DOI']) & 
    pd.isna(book_journal_features['PMID']) &
    pd.isna(book_journal_features['PMC']) &
    book_journal_features['citation_type'].isin(['cite journal', 'cite conference'])
)
book_journal_features.loc[both_book_and_doi_journal, ['actual_label']] = 'journal'

both_book_and_doi_book = (
    ~pd.isna(book_journal_features['ISBN']) & 
    ~pd.isna(book_journal_features['DOI']) & 
    pd.isna(book_journal_features['PMID']) &
    pd.isna(book_journal_features['PMC']) &
    book_journal_features['citation_type'].isin(['cite book', 'cite encyclopedia'])
)
book_journal_features.loc[both_book_and_doi_book, ['actual_label']] = 'book'

## Made the dataset which contains citations book and journal labeled
book_journal_features = book_journal_features[book_journal_features['actual_label'].isin(['book', 'journal'])]
book_journal_features = book_journal_features[[
    'sections', 'citation_type', 'citation', 'id', 'ref_index',
     'total_words', 'neighboring_tags', 'actual_label', 'neighboring_words'
]]
print(book_journal_features.shape)

## loading the dataset of newspapers which was generated from the citations_separated dataset
li = []
all_files = glob.glob('/dlabdata1/harshdee/newspapers_citations_features.csv/' + "/*.csv")

for filename in all_files:
    df = pd.read_csv(filename, header=None, sep='\t')
    li.append(df)

newspaper_data = pd.concat(li, axis=0, ignore_index=True)
newspaper_data.shape

newspaper_data = newspaper_data[[0, 1, 2, 3, 4, 28, 32, 33]]
newspaper_data.rename({
    0: 'citation', 1: 'ref_index', 2: 'total_words',
    3: 'neighboring_words', 4: 'neighboring_tags', 
    28: 'id', 32: 'sections', 33: 'citation_type'}, axis=1, inplace=True)
newspaper_data['actual_label'] = 'newspaper'

entertainment_features = pd.read_parquet(
    '/dlabdata1/harshdee/entertainment_citations_complete.parquet/', engine='pyarrow')

entertainment_features = entertainment_features[[
    'ref_index', 'total_words', 'neighboring_words', 'neighboring_tags', 'id', 'sections', 'citations']]
entertainment_features.rename({'citations': 'citation'}, axis=1, inplace=True)

entertainment_features['actual_label'] = 'entertainment'
newspaper_data.drop('citation_type', axis=1, inplace=True)
book_journal_features.drop('citation_type', axis=1, inplace=True)

dataset_with_features = pd.concat([book_journal_features, newspaper_data, entertainment_features])
print(dataset_with_features.shape)

le = preprocessing.LabelEncoder()
le.fit(dataset_with_features['actual_label'])
dataset_with_features['label_category'] = le.transform(dataset_with_features['actual_label'])
## Remove rows which have duplicate ID and citations since they are just the same examples
dataset_with_features = dataset_with_features.drop_duplicates(subset=['id', 'citation']) ## keeps first row

del citations_features
del dataset
del book_journal_features
del newspaper_data
del entertainment_features
gc.collect()

## Get the top 150 sections which we got from training the 2.7 million citations
largest_sections = pd.read_csv('/dlabdata1/harshdee/largest_sections.csv', header=None)
largest_sections.rename({0: 'section_name', 1: 'count'}, axis=1, inplace=True)

original_tag_counts = pd.read_csv('/dlabdata1/harshdee/tag_counts.csv', header=None)
original_tag_counts.rename({0: 'tag', 1: 'count'}, axis=1, inplace=True)

# Load the pretrained embedding model on wikipedia
model_fasttext = FastText.load_fasttext_format('/dlabdata1/harshdee/wiki.en.bin')
model_embedding = load_model('/dlabdata1/harshdee/embedding_model.h5')


def make_structure_time_features(time_features):
    """
    Concatenate features which are numbers and lists together by checking the type:

    param: time_features: the features which are considered time sequence.
    """
    feature_one = np.array([i for i in time_features if isinstance(i, numbers.Number)])
    feature_two = np.array([i for i in time_features if isinstance(i, list)][0])
    return np.array([feature_one, feature_two])

def get_reduced_words_dimension(data):
    """
    Get the aggregated dataset of words and tags which has the
    same dimensionality using PCA.

    :param: data: data which needs to be aggregated.
    """
    tags = [i for i, _ in data]
    word_embeddings = [j for _,j in data]
    pca = PCA(n_components=35)
    pca.fit(word_embeddings)

    word_embeddings_pca = pca.transform(word_embeddings)
    tags = np.array(tags)
    return np.dstack((word_embeddings_pca, tags))


# ### Get auxiliary features and divide them into labels and get predictions
# 
# 1. `ref_index`
# 2. `total_words`
# 3. `tags`
# 4. `section`

PATH = '/dlabdata1/harshdee/citations_features_complete.parquet/'

for index__, f_name in enumerate(os.listdir(PATH)):
    if f_name == '_SUCCESS':
        continue
    print('Doing filename: {}'.format(f_name))
    f_name_path = '{}{}'.format(PATH, f_name)
    wild_examples = pd.read_parquet(f_name_path, engine='pyarrow')
    wild_examples = wild_examples[~wild_examples['citations'].isin(dataset_with_features['citation'])].reset_index(drop=True)
    print('Number of wild citations in this file: {}'.format(wild_examples.shape))

    print('Any sections in the parent section: {}'.format(not any([True if i in list(largest_sections['section_name']) else False for i in set(wild_examples['sections'])])))
    # Only processing auxiliary features which are going to be used in the neural network
    auxiliary_features = wild_examples[['sections', 'citations', 'ref_index', 'neighboring_words', 'total_words', 'neighboring_tags']]

    ###### SECTION GENERATION ########
    auxiliary_features['sections'] = auxiliary_features['sections'].astype(str)
    auxiliary_features['sections'] = auxiliary_features['sections'].progress_apply(lambda x: x.split(', '))
    # Change section to `OTHERS` if occurence of the section is not in the 150 largest sections
    auxiliary_features['sections'] = auxiliary_features['sections'].progress_apply(
        lambda x: list(set(['Others' if i not in list(largest_sections['section_name']) else i for i in x]))
    )
    section_dummies = pd.get_dummies(auxiliary_features['sections'].progress_apply(pd.Series).stack())
    residual_sections = set(list(largest_sections['section_name'])) - set(section_dummies.columns)
    if len(residual_sections) > 0:
        for r_s in residual_sections:
            section_dummies[r_s] = 0
    auxiliary_features = auxiliary_features.join(section_dummies.sum(level=0))
    auxiliary_features.drop('sections', axis=1, inplace=True)
    print('Shape of auxiliary features after section generation: {}'.format(auxiliary_features.shape))
    ###### SECTION GENERATION ########


    citation_tag_features = auxiliary_features[['citations', 'neighboring_tags']]
    # Get the count for each POS tag so that we have an estimation as to how many are there
    tag_counts = pd.Series(Counter(chain.from_iterable(x for x in citation_tag_features.neighboring_tags)))
    print('Is this the subset of the parent: {}'.format(set(tag_counts.index).issubset(list(original_tag_counts['tag']))))
    OTHER_TAGS = ['LS', '``', '$']
    citation_tag_features['neighboring_tags'] = citation_tag_features['neighboring_tags'].progress_apply(
        lambda x: [i if i not in OTHER_TAGS else 'Others' for i in x]
    )
    citation_tag_features['neighboring_tags'] = [['Others'] if not x else x for x in citation_tag_features['neighboring_tags']]
    cv = CountVectorizer() # Instantiate the vectorizer
    citation_tag_features['neighboring_tags'] = citation_tag_features['neighboring_tags'].progress_apply(lambda x: " ".join(x))
    transformed_neighboring_tags = cv.fit_transform(citation_tag_features['neighboring_tags'])
    transformed_neighboring_tags = pd.DataFrame(transformed_neighboring_tags.toarray(), columns=cv.get_feature_names())
    citation_tag_features = pd.concat([citation_tag_features, transformed_neighboring_tags], join='inner', axis=1)
    citation_tag_features.drop('neighboring_tags', axis=1, inplace=True)

    ###### GENERATE TEXT FEATURES ########
    citation_text_features = auxiliary_features['citations']
    # Convert the citation into a list by breaking it down into characters
    citation_text_features = citation_text_features.progress_apply(lambda x: list(x))
    char_counts = pd.Series(Counter(chain.from_iterable(x for x in citation_text_features)))
    char2ind = {char: i for i, char in enumerate(char_counts.index)}
    ind2char = {i: char for i, char in enumerate(char_counts.index)}
    # Map each character into the citation to its corresponding index and store it in a list
    X_char = []
    for citation in citation_text_features:
        citation_chars = []
        for character in citation:
            citation_chars.append(char2ind[character])
        X_char.append(citation_chars)
    X_char = pad_sequences(X_char, maxlen=400)
    citation_layer = model_embedding.get_layer('citation_embedding')
    citation_weights = citation_layer.get_weights()[0]
    citation_text_features = citation_text_features.to_frame()
    # Map the embedding of each character to the character in each corresponding citation and aggregate (sum)
    citation_text_features['embedding'] = citation_text_features['citations'].progress_apply(lambda x: sum([citation_weights[char2ind[c]] for c in x]))
    # Normalize the citation embeddings so that we can check for their similarity later
    citation_text_features['embedding'] = citation_text_features['embedding'].progress_apply(lambda x: x/ np.linalg.norm(x, axis=0).reshape((-1, 1)))


    #### GENERATE WORD FEATURES #####
    citation_word_features = auxiliary_features[['citations', 'neighboring_words']]
    citation_word_features['neighboring_words'] = citation_word_features['neighboring_words'].progress_apply(lambda x: [i.lower() for i in x])
    word_counts = pd.Series(Counter(chain.from_iterable(x for x in citation_word_features.neighboring_words)))
    threshold = 4
    x = len(word_counts)
    y = len(word_counts[word_counts <= threshold])
    print('Total words: {}\nTotal number of words whose occurence is less than 4: {}\nDifference: {}'.format(x, y, x-y))
    words_less_than_threshold = word_counts[word_counts <= threshold]
    citation_word_features['neighboring_words'] = citation_word_features['neighboring_words'].progress_apply(
        lambda x: [i if i not in words_less_than_threshold else '<UNK>' for i in x]
    )
    citation_word_features['neighboring_words'] = [['<UNK>'] if not x else x for x in citation_word_features['neighboring_words']]
    words = pd.Series(Counter(chain.from_iterable(x for x in citation_word_features.neighboring_words))).index
    word2ind = {w: i for i, w in enumerate(words)}
    ind2words = {i: w for i, w in enumerate(words)}
    word_embedding_matrix = np.zeros((len(word2ind), 300))
    for w in tqdm(word2ind):
        word_embedding_matrix[word2ind[w]] = model_fasttext.wv[w]
    citation_word_features['words_embedding'] = citation_word_features['neighboring_words'].progress_apply(lambda x: sum([word_embedding_matrix[word2ind[w]] for w in x]))
    # Join time sequence features with the citations dataset
    time_sequence_features = pd.concat([citation_tag_features, citation_word_features], keys=['id', 'citation'], axis=1)
    time_sequence_features = time_sequence_features.loc[:, ~time_sequence_features.columns.duplicated()]
    print('Total number of samples in time features are: {}'.format(time_sequence_features.shape))

    # Join auxiliary features with the citations dataset
    citation_text_features.reset_index(drop=True, inplace=True)
    auxiliary_features.reset_index(drop=True, inplace=True)
    auxiliary_features = pd.concat([auxiliary_features, citation_text_features], keys=['id', 'citation'], axis=1)
    auxiliary_features = pd.concat([auxiliary_features['citation'], auxiliary_features['id']], axis=1)
    auxiliary_features = auxiliary_features.loc[:, ~auxiliary_features.columns.duplicated()]
    print('Auxiliary features are: {}'.format(auxiliary_features.shape))
    auxiliary_features.drop(['neighboring_tags'], axis=1, inplace=True)

    ### Making sets for `auxiliary` and `time sequence` features ###
    print('Auxiliary: {} Time: {}'.format(auxiliary_features.shape, time_sequence_features.shape))
    time_sequence_features = pd.concat([time_sequence_features['id'], time_sequence_features['citation']], axis=1)
    time_sequence_features['words_embedding'] = [np.array([]) if not isinstance(x, np.ndarray) else x for x in time_sequence_features['words_embedding']]
    time_sequence_features['words_embedding'] = time_sequence_features['words_embedding'].progress_apply(lambda x: list(x))
    auxiliary_features['embedding'] = auxiliary_features['embedding'].progress_apply(lambda x: x.tolist())

    # Make a mask for auxiliary dataset to get all features except the one below
    column_mask_aux = ~auxiliary_features.columns.isin(['citations', 'neighboring_words'])
    testing_auxiliary = auxiliary_features.loc[:, column_mask_aux].values.tolist()
    testing_auxiliary = [np.array(testing_auxiliary[i][0][0] + testing_auxiliary[i][1:]) for i in tqdm(range(len(testing_auxiliary)))]

    cols = [col for col in time_sequence_features.columns if col not in ['citations', 'neighboring_words']]
    stripped_tsf = time_sequence_features[cols]
    testing_time = stripped_tsf.values.tolist()
    testing_time = [make_structure_time_features(testing_time[i]) for i in tqdm(range(len(testing_time)))]
    test_pca = get_reduced_words_dimension(testing_time)
    print('Features for model constructed.. now running model')

    ### RUN MODEL ####
    model = load_model('/dlabdata1/harshdee/folds/citation_model_fold_4.h5')
    prediction = model.predict([test_pca, np.array(testing_auxiliary)])
    print('Shape of prediction: {}'.format(prediction.shape))
    y_pred = np.argmax(prediction, axis=1)
    wild_examples['label_category'] = y_pred
    print('Done with model prediction for index: {}'.format(index__))

    ### Result saved ####
    wild_examples[['citations', 'label_category']].to_csv('/dlabdata1/harshdee/results/result_{}.csv'.format(index__), index=False)
    print('\nFile saved for part: {}\n\n'.format(index__))

