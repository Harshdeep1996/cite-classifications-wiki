# -*- coding: utf-8 -*-
"""
Helper functions for extraction of citation templates from Wiki dump.
"""

import re
import mwparserfromhell

PUNCTUATION_TO_BE_REMOVED = '"#$%\'()*+/:;<=>?@[\\]^_`{|}~'
PUNC_REGEX = re.compile(r'[{}]+'.format(re.escape(PUNCTUATION_TO_BE_REMOVED)))

def check_if_balanced(my_string):
    """
    Check if particular citation has balanced brackets.

    :param: citation to be taken in consideration
    """
    my_string = re.sub('\w|\s|[^{}]','', my_string)
    brackets = ['()', '{}', '[]'] 
    while any(x in my_string for x in brackets): 
        for br in brackets: 
            my_string = my_string.replace(br, '') 
    return not my_string

def get_citations(page_content):
    """
    Get the <ref></ref> tag citations and citations which are standalone in a format, for e.g. "* {{"
    :param: page_content: <text></text> part of the wikicode xml.
    """
    wikicode = mwparserfromhell.parse(page_content)
    templates = wikicode.filter_templates()
    section_features = wikicode.get_node_sections_feature()

    citations = []
    sections = []
    for tpl in templates:
        # c_exists = regex.findall(CITATION_REGEX, repr(tpl))
        if tpl.startswith('{{'):
            citations.append(repr(tpl))
            sections.append(', '.join(section_features[tpl]))

    return zip(citations, sections)

def get_features(page_content):
    wikicode = mwparserfromhell.parse(page_content)
    templates = wikicode.filter_templates()
    section_features = wikicode.get_node_sections_feature()

    all_words = wikicode.get_all_tokens_feature()
    all_words = [repr(w) for w in all_words]

    results = []
    for tpl in templates:
        if tpl.startswith('{{'):
            sections = section_features[tpl]
            results.append([repr(tpl), sections, all_words])

    return results

def get_citation_all_words(title, page_content):
    wikicode = mwparserfromhell.parse(page_content)

    # Get all words for a page associated with a title
    all_words = wikicode.get_all_tokens_feature()
    all_words = [repr(w) for w in all_words]

    return [(title, all_words)]
