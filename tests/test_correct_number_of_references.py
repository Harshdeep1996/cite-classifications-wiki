import os
import glob
import unittest
import pandas as pd
import mwparserfromhell

# Using the forked library
from wikiciteparser.parser import parse_citation_template


def get_parsed_citations(content):
    parsed_cites = []

    # Go through each of the templates
    wikicode = mwparserfromhell.parse(content)
    templates = wikicode.filter_templates()
    for tpl in templates:
        citation = parse_citation_template(tpl)
        if citation:
            type_of_citation = tpl.split('|')[0].lower()[2:]
            parsed_cites.append((citation, type_of_citation))
    return parsed_cites


class TestCorrectNumberOfReferences(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        files = glob.glob('tests/data/random_pages.csv/part-*')
        random_pages_dfs = [pd.read_csv(f, header=None, sep=',') for f in files if os.path.getsize(f) > 0]

        # Considering just the title and content of the page
        cls.random_pages = pd.concat(random_pages_dfs, ignore_index=True)[[1, 2]]

    def test_check_refs_page_one(self):
        # This is a sports page - related to some AFL player
        title, content = self.random_pages.iloc[0]
        parsed_cites = get_parsed_citations(content)
        manual_counting = 14

        self.assertEquals(len(parsed_cites), manual_counting)

        # All of the citations are cite web
        self.assertTrue(all([t == 'cite web' for _,t in parsed_cites]))

    def test_check_refs_page_two(self):
        # It is basically about a Japan Prefecture which does not exist
        title, content = self.random_pages.iloc[1]
        parsed_cites = get_parsed_citations(content)
        manual_counting = 0

        self.assertEquals(len(parsed_cites), manual_counting)

        # No word cite even in the whole article
        self.assertFalse('cite' in content)

    def test_check_refs_page_three(self):
        # It is basically a page about a writer and contains a citation for which
        # we do not have the template right now
        title, content = self.random_pages.iloc[2]
        parsed_cites = get_parsed_citations(content)
        manual_counting = 0

        self.assertEquals(len(parsed_cites), manual_counting)

        # 'cite' exists in the text - but not covered by wikiciteparser
        self.assertTrue('cite DNB' in content)

    def test_check_refs_page_four(self):
        # This page is about a Republician election in the USA
        title, content = self.random_pages.iloc[3]
        parsed_cites = get_parsed_citations(content)
        manual_counting = 3

        # Added a test citation from a new format like harvnb
        self.assertEquals(len(parsed_cites), manual_counting)

        # One of the citations is a harvnb
        self.assertTrue(any([t == 'harvnb' for _,t in parsed_cites]))

    def test_check_refs_page_five(self):
        # This is about a city in Iran - a test case for geolocation
        title, content = self.random_pages.iloc[4]
        parsed_cites = get_parsed_citations(content)
        manual_counting = 1

        # Added a test citation from a new format like geonet3 - naturally
        self.assertEquals(len(parsed_cites), manual_counting)

        # One of the citations is a harvnb
        self.assertTrue(
            any([t == 'geonet3' for _,t in parsed_cites]) and 'IranCensus2006' in content
        )

if __name__ == '__main__':
    unittest.main()
