# -*- coding: utf-8 -*-

import re
import regex
import mwparserfromhell
from bs4 import BeautifulSoup


CITATION_REGEX = (
    '{{\s?ci[\w\s]*[^}]*}}(?:}}(?R)?)?|{{\s?Ci[\w\s]*[^}]*}}(?:}}(?R)?)?|'
    '{{\s?h[\w\s]*[^}]*}}(?:}}(?R)?)?|{{\s?H[\w\s]*[^}]*}}(?:}}(?R)?)?'
)

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

    wikicode_tpl = mwparserfromhell.parse(page_content)
    templates = wikicode_tpl.filter_templates()

    citations = []
    for tpl in templates:
        c_exists = regex.findall(CITATION_REGEX, str(tpl))
        if c_exists:
            citations.append(c_exists[0])

    return citations
