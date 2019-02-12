# Large-scale automatic classification of references in Wikipedia.

**Goals:**

1. Extract all references from Wikipedia English. This task is non-trivial as references use a variety of templates. Resources exist to do this step.
2. Uniform references across templates. E.g. a template might indicate the author as "author", another as "creator". Uniform that into a unique schema. Resources exist to do this step.
3. Clarify all references as "to scientific publications" (scientific, books - DOI, ISBN) (1) or "not" (0), using as training data the references containing known identifiers (e.g. DOI). Training data is already provided by Wikimedia research, see below.
4. Look-up all references to scientific publications without an identifier to existing services
5. Export a finalized dataset and release project code publicly.

## Previous work and resources

Previous work has considered references to scientific publications with known identifiers such as DOIs and ISBNs, see <https://wikimediafoundation.org/2018/08/20/how-many-wikipedia-references-are-available-to-read/> and <https://www.nature.com/articles/d41586-018-05161-6>.

Existing resources:

* [Wikicite data](https://github.com/wikicite/wikicite-data): code to extract, transform, and analyze bibliographic data from Wikidata dumps.
* [MWCites](https://github.com/mediawiki-utilities/python-mwcites): code to extract citations from Wikidata dumps. See also (for citation contexts): [MWRefs](https://github.com/mediawiki-utilities/python-mwrefs).
* [Citations in context](https://figshare.com/articles/_/5588842): a dataset of structured metadata and contextual information about references added to Wikipedia articles in a JSON format.
* [Citations with identifiers in Wikipedia](https://figshare.com/articles/Wikipedia_Scholarly_Article_Citations/1299540)
* [Crossref APIs](https://github.com/CrossRef/rest-api-doc).
