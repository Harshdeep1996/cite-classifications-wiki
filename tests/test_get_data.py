import unittest
from scripts.helpers import get_citations, check_if_balanced


class TestGetData(unittest.TestCase):

    def test_check_standalone_citation_works(self):
        citation_text = '* {{Cite news | url=https://test.com | author=Mr.x}}'
        original_citations = list(get_citations(citation_text))
        expected_citations = ["u'{{Cite news | url=https://test.com | author=Mr.x}}'"]

        self.assertListEqual(original_citations, expected_citations)

    def test_check_standalone_harvard_citation_works(self):
        citation_text = '* {{harvnb | url=https://test.com | author=Mr.x}}'
        original_citations = list(get_citations(citation_text))
        expected_citations = ["u'{{harvnb | url=https://test.com | author=Mr.x}}'"]

        self.assertListEqual(original_citations, expected_citations)

    def test_check_matches_multiple_brackets(self):
        citation_text = '* {{Cite news | url=https://test.com | author=Mr.x | ref={{sfnref|harvey|1989}}}}'
        original_citations = list(get_citations(citation_text))
        expected_citations = [
            "u'{{Cite news | url=https://test.com | author=Mr.x | ref={{sfnref|harvey|1989}}}}'",
            "u'{{sfnref|harvey|1989}}'"
        ]
        # self.assertListEqual(original_citations, expected_citations)

    def test_check_not_matches_multiple_brackets(self):
        citation_text = '* {{Cite news | url=https://test.com | author=Mr.x | ref={{sfnref|harvey|1989}} }}'
        original_citations = list(get_citations(citation_text))
        expected_citations = [
            ('{{Cite news | url=https://test.com | author=Mr.x | ref={{sfnref|harvey|1989}} }}',
            ['Initial Section'])
        ]

        with self.assertRaises(AssertionError):
            self.assertListEqual(original_citations, expected_citations)

    def test_check_citation_matches_in_ref_tag(self):
        citation_text = '<ref>{{Cite news | url=https://test.com | author=Mr.x}}</ref>'
        original_citations = list(get_citations(citation_text))
        expected_citations = ["u'{{Cite news | url=https://test.com | author=Mr.x}}'"]

        self.assertListEqual(original_citations, expected_citations)

    def test_check_citation_matches_in_ref_tag_with_space_in_beginning(self):
        citation_text = '<ref>{{ cite journal | url=https://test.com | author=Mr.x}}</ref>'
        original_citations = list(get_citations(citation_text))
        expected_citations =  ["u'{{ cite journal | url=https://test.com | author=Mr.x}}'"]

        self.assertListEqual(original_citations, expected_citations)

    def test_check_citation_not_matches_ref_tag_multiple_brackets(self):
        citation_text = '<ref>{{Cite news | url=https://test.com | author=Mr.x | ref={{sfnref|harvey|1989}} }}</ref>'
        original_citations = list(get_citations(citation_text))
        expected_citations = [
            "u'{{Cite news | url=https://test.com | author=Mr.x | ref={{sfnref|harvey|1989}} }}'",
            "u'{{sfnref|harvey|1989}}'"
        ]

        self.assertListEqual(original_citations, expected_citations)


if __name__ == '__main__':
    unittest.main()
