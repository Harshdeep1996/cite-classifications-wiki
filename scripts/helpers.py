# -*- coding: utf-8 -*-

import re
import regex
import mwparserfromhell
# from bs4 import BeautifulSoup


# CITATION_REGEX = (
#     '{{\s?ci[\w\s]*[^}]*}}(?:}}(?R)?)?|{{\s?Ci[\w\s]*[^}]*}}(?:}}(?R)?)?|'
#     '{{\s?h[\w\s]*[^}]*}}(?:}}(?R)?)?|{{\s?H[\w\s]*[^}]*}}(?:}}(?R)?)?'
# )

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
    all_words = wikicode.get_all_tokens_feature()

    results = []
    for tpl in templates:
        if tpl.startswith('{{'):
            sections = section_features[tpl]
            results.append((repr(tpl), sections, all_words))

    return results
