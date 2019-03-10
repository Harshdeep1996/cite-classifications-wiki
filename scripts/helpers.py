# -*- coding: utf-8 -*-

import re
import regex
from io import StringIO
from bs4 import BeautifulSoup


CITATION_REGEX = (
    '{{ci[\w\s]*[^}]*}}(?:}}(?R)?)?|{{Ci[\w\s]*[^}]*}}(?:}}(?R)?)?|'
    '{{h[\w\s]*[^}]*}}(?:}}(?R)?)?|{{H[\w\s]*[^}]*}}(?:}}(?R)?)?'
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
    citations = dict()
    refs_in_line = []
    buf = StringIO(page_content)
    current_section = 'Initial Section'

    for line in buf.readlines():
        if line.startswith('== '):
            current_section = line.strip()
        elif line.startswith('* {{'):
            refs_in_line = regex.findall(CITATION_REGEX, line)
        else:
            refs_in_line = [r.text for r in BeautifulSoup(repr(line)).findAll('ref') if r.text]

        if not refs_in_line:
            continue

        for ref in refs_in_line:
            potential_citation = regex.findall(CITATION_REGEX, ref)
            if not potential_citation:
                continue

            # Append section in which the citation was present
            for c in potential_citation:
                citations.setdefault(c, [])
                if current_section not in citations[c]:
                    citations[c].append(current_section)

    return citations.items()
