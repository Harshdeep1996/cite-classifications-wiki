# Large-scale automatic classification of references in Wikipedia.

**The documentation is written as WIKI in: [DOCUMENTATION](https://github.com/Harshdeep1996/cite-classifications-wiki/wiki)**

A dataset of citations is extracted from English Wikipedia which comprises of 29 different templates such as `cite news`, `cite web`. 

The dataset contains 23.80 million citations and then a subset is prepared which contains citations with identifiers which is 3.14 millions in size. The citations with identifiers dataset only covers the DOI, ISBN, PMC, PMID, ArXIV identifiers. 

Along with the 2 dataset of citations, 2 frameworks are written to train the citations and get the classification - if the citation is scientific or not. Anyone is open to build models or do experiments using the extracted datasets and improve our results!

## Contents

* `README.md` this file.
* `data/`
    * [citations_separated](data/citation_separated.parquet): Dataset containing all citations from Wikipedia with each of the column keys separated and compress in parquet format.
    * [citations_ids](data/citations_ids.csv) Subset of the above dataset but containing all citation which have a valid identifier such as DOI, ISBN, PMC, PMID or ArXIV.
    * [top300_templates](data/top300_templates.csv) A CSV file which contains the TOP 300 csv templates as calculated by DLAB-EPFL. 
* `models/random_forest.ipynb` a Python notebook to train a Random Forest model which does citation classification task. The training/testing set can be generated from the notebook.
* `models/citation_network.ipynb` a Python notebook to train a deep learning (LSTMs, Neural Nets) model which does citation classification task. The training/testing set can be generated from the notebook.
* `mwparserfromhell/` The forked parser library which parses Wikicode page content. It has been forked since we needed to do some changes to the parsing library.
* `scripts/`
    * `features/`
      * [filter by page content](scripts/features/filter_contents.py) out of all the wikipedia pages, get pages which we are interested in getting the features for.
      * [extract NLP features](scripts/features/extract_nlp_features.py) Generate features for those pages by considering the page content.
      * [get features for dataset](scripts/features/get_dataset_features.py) Join the generated features with the citations and do some cleaning to the structure of the dataframe.
