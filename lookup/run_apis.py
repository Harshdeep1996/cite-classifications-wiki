# -*- coding: utf-8 -*-
"""
Able to do synchronous requests to Google Books and CrossRef APIs for metadata extraction.

These methods should be used for small loads of metadata extraction.
"""

import requests


GOOGLE_BOOKS_PREFIX = 'https://www.googleapis.com/books/v1/volumes?'
CROSSREF_WORKS_PREFIX = 'https://api.crossref.org/works'

# The Google BOOK APIs - https://developers.google.com/books/docs/v1/using
def run_google_book_get_id(query, intitle=None, inauthor=None, inpublisher=None):
    """
    Given some information about the author, publisher, name of book - find the relevant IDs.
    The user needs to give one parameter atleast for the search to happen.

    :param: query: some relevant text related to the book.
    """
    if all(v is None for v in {intitle, inauthor, inpublisher}):
        raise ValueError('Please give some information about the book - author, publisher, title')

    url_to_be_queried = '{}q={}'.format(GOOGLE_BOOKS_PREFIX, query)
    if inauthor:
        url_to_be_queried = '{}+inauthor:{}'.format(url_to_be_queried, inauthor)
    if intitle:
        url_to_be_queried = '{}+intitle:{}'.format(url_to_be_queried, intitle)
    if inpublisher:
        url_to_be_queried = '{}+inpublisher:{}'.format(url_to_be_queried, inpublisher)

    r = requests.get(url_to_be_queried)
    return r


def run_google_book_get_info(isbn=None, oclc=None):
    """
    Given some information about the ids like ISBN - find the relevant book information.
    The user needs to give one parameter atleast for the search to happen.

    :param: isbn: the isbn id of the book (optional)
    :param: oclc: the oclc id of the book (optional)
    """
    url_to_be_queried = ''
    if all(v is None for v in {isbn, oclc}):
        raise ValueError('Please give some ID for the book - ISBN, OCLC')

    if isbn:
        url_to_be_queried = '{}q=isbn:{}'.format(GOOGLE_BOOKS_PREFIX, isbn)
    else:
        url_to_be_queried = '{}q=oclc:{}'.format(GOOGLE_BOOKS_PREFIX, isbn)

    r = requests.get(url_to_be_queried)
    return r


# The CrossRef APIs

def run_cross_ref_get_id(title=None, author=None):
    """
    Given some information about the author, name of book - find the relevant IDs.
    The user needs to give one parameter atleast for the search to happen.

    :param: title: The title of the book (optional)
    :param: author: The author of the book (optional)
    """
    if all(v is None for v in {title, author}):
        raise ValueError('Please give some information about the book - author, title for Crossref')
    url_to_be_queried = '{}?rows=1'.format(CROSSREF_WORKS_PREFIX)
    if author:
        url_to_be_queried = '{}&query.author={}'.format(url_to_be_queried, author)
    if title:
        title_prefix = '&query.title='
        url_to_be_queried = '{}{}{}'.format(url_to_be_queried, title_prefix, title)
    r = requests.get(url_to_be_queried)
    return r

def run_crossref_get_info(doi=None, isbn=None):
    """
    Run the Crossref API using a DOI to get information about that document.

    :param: doi: the doi ID of that document.
    :param: isbn: the ISBN ID of the document.
    """
    if not doi and not isbn:
        raise ValueError('Please mention the identifier of the document')

    url_to_be_queried = '{}'.format(CROSSREF_WORKS_PREFIX)
    if doi:
        url_to_be_queried = '{}/{}'.format(url_to_be_queried, doi)
    else:
        url_to_be_queried = '{}?filter=isbn:{}'.format(url_to_be_queried, isbn)

    r = requests.get(url_to_be_queried)
    return r