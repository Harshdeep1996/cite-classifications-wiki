# Large-scale automatic classification of references in Wikipedia.

**The documentation is written as WIKI in: [DOCUMENTATION](https://github.com/Harshdeep1996/cite-classifications-wiki/wiki)**

A dataset of citations is extracted from English Wikipedia (date: May 2020) which comprises of 35 different templates such as `cite news`, `cite web`. 

The dataset contains 29.276 million citations and then a subset is prepared which contains citations with identifiers which is 3.92 millions in size. The citations with identifiers dataset only covers the DOI, ISBN, PMC, PMID, ArXIV identifiers. 

Along with the 2 dataset of citations, 2 frameworks are written to train the citations and get the classification - if the citation is scientific or not. Anyone is open to build models or do experiments using the extracted datasets and improve our results!

## Running the repository

Assuming that Python is already installed (tested with version >= 2.7), the list of dependenices is written in `requirements.txt`, the libraries can be installed using:

```
pip install requirements.txt
```

The notebooks can be accessed using:

```
jupyter notebook
```

## Contents

* `README.md` this file.
* `data/`
    * [citations_separated](data/citations_separated.parquet): Dataset containing all citations from Wikipedia with each of the column keys separated and compress in parquet format **(pre lookup)**.
    * [citations_ids](data/citations_ids.csv) Subset of the above dataset but containing all citation which have a valid identifier such as DOI, ISBN, PMC, PMID or ArXIV.
    * [top300_templates](data/top300_templates.csv) A CSV file which contains the TOP 300 csv templates as calculated by DLAB-EPFL.
* `libraries/`: Contains the libraries `mwparserfromhell` and `wikiciteparser` which have been changed for the scope of the project. To get all the datasets, the user would need to install these versions of the libraries.
* `lookup`: Contains two scripts `run_metadata.py` and `get_apis.py` which can be used to query CrossRef and Google books. `run_metadata.py` script is run asynchronously and right now can only be used for CrossRef. `get_apis.py` uses the `requests` library and can be used for querying short loads of metadata. Other files are related to the crossref evaluation to known what is the best heuristic and confidence threshold.
* `notebooks`: Contains the notebooks which  -- 
   * do analysis against some other similar work (`Sanity_Check_Citations.ipynb`)
   * play with features (`Feature_Data_Analysis.ipynb`)
   * the hybrid network model which does the classification for the examples and contains all the steps (`citation_network_model_3_labels.ipynb`)
   * some of the results and which we get from the lookup -- and the corresponding label we classify them into (`results_predication_lookup.ipynb`)
   * doing post lookup steps such as linking the potential journal labeled citations with their corresponding metadata (`wild_examples_lookup_journal.ipynb`)
* `scripts`: Contains all the scripts to generate the dataset and features. For each script, a description is given at the top. All the paths to files are currently **absolute paths used to run the script** -- so please remember while running these scripts to change them.
* `tests`: Some tests to check if the scripts for the data generation do what they are supposed to. Multiple tests would be added in the future to check the whole pipeline.
