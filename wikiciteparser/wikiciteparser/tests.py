# -*- encoding: utf-8 -*-
from __future__ import unicode_literals

import unittest
from wikiciteparser.parser import *


class ParsingTests(unittest.TestCase):
    def test_multiple_authors(self):
        p = parse_citation_dict({"doi": "10.1111/j.1365-2486.2008.01559.x",
                                 "title": "Climate change, plant migration, and range collapse in a global biodiversity hotspot: the ''Banksia'' (Proteaceae) of Western Australia",
                                 "issue": "6",
                                 "journal": "Global Change Biology",
                                 "year": "2008",
                                 "volume": "14",
                                 "last4": "Dunn",
                                 "last1": "Fitzpatrick",
                                 "last3": "Sanders",
                                 "last2": "Gove", "first1":
                                 "Matthew C.",
                                 "first2": "Aaron D.",
                                 "first3": "Nathan J.",
                                 "first4": "Robert R.",
                                 "pages": "1\u201316"
                                 },
                                template_name='cite journal')
        self.assertEqual(p['Authors'], [{'last': 'Fitzpatrick',
                                         'first': 'Matthew C.'
                                         },
                                        {'last': 'Gove',
                                         'first': 'Aaron D.'},
                                        {'last': 'Sanders',
                                         'first': 'Nathan J.'},
                                        {'last': 'Dunn',
                                         'first': 'Robert R.'
                                         }
                                        ])

    def test_vauthors(self):
        p = parse_citation_dict({"doi": "10.1016/s1097-2765(00)80111-2",
                                 "title": "SAP30, a component of the mSin3 corepressor complex involved in N-CoR-mediated repression by specific transcription factors",
                                 "journal": "Mol. Cell",
                                 "volume": "2",
                                 "date": "July 1998",
                                 "pmid": "9702189",
                                 "issue": "1",
                                 "pages": "33\u201342",
                                 "vauthors": "Laherty CD, Billin AN, Lavinsky RM, Yochum GS, Bush AC, Sun JM, Mullen TM, Davie JR, Rose DW, Glass CK, Rosenfeld MG, Ayer DE, Eisenman RN"
                                 },
                                template_name='cite journal')
        self.assertEqual(p['Authors'], [{'last': 'Laherty',
                                         'first': 'CD'
                                         },
                                        {'last': 'Billin',
                                         'first': 'AN'
                                         },
                                        {'last': 'Lavinsky',
                                         'first': 'RM'
                                         },
                                        {'last': 'Yochum',
                                         'first': 'GS'
                                         },
                                        {'last': 'Bush',
                                         'first': 'AC'
                                         },
                                        {'last': 'Sun',
                                         'first': 'JM'
                                         },
                                        {'last': 'Mullen',
                                         'first': 'TM'
                                         },
                                        {'last': 'Davie',
                                         'first': 'JR'
                                         },
                                        {'last': 'Rose',
                                         'first': 'DW'
                                         },
                                        {'last': 'Glass',
                                         'first': 'CK'
                                         },
                                        {'last': 'Rosenfeld',
                                         'first': 'MG'
                                         },
                                        {'last': 'Ayer',
                                         'first': 'DE'
                                         },
                                        {'last': 'Eisenman',
                                         'first': 'RN'
                                         }
                                        ])

    def test_remove_links(self):
        p = parse_citation_dict({"title": "Mobile, Alabama",
                                 "url": "http://archive.org/stream/ballouspictorial1112ball#page/408/mode/2up",
                                 "journal": "[[Ballou's Pictorial Drawing-Room Companion]]",
                                 "volume": "12",
                                 "location": "Boston",
                                 "date": "June 27, 1857"
                                 },
                                template_name='cite journal')
        self.assertEqual(p['Periodical'],
                         "Ballou's Pictorial Drawing-Room Companion")

    def test_authorlink(self):
        p = parse_citation_dict({"publisher": "[[World Bank]]",
                                 "isbn": "978-0821369418",
                                 "title": "Performance Accountability and Combating Corruption",
                                 "url": "http://siteresources.worldbank.org/INTWBIGOVANTCOR/Resources/DisruptingCorruption.pdf",
                                 "page": "309",
                                 "last1": "Shah",
                                 "location": "[[Washington, D.C.]], [[United States|U.S.]]",
                                 "year": "2007",
                                 "first1": "Anwar",
                                 "authorlink1": "Anwar Shah",
                                 "oclc": "77116846"
                                 },
                                template_name='citation')
        self.assertEqual(p['Authors'], [{'link': 'Anwar Shah',
                                         'last': 'Shah',
                                         'first': 'Anwar'
                                         }
                                        ])

    def test_unicode(self):
        p = parse_citation_dict({"title": "\u0414\u043e\u0440\u043e\u0433\u0438 \u0446\u0430\u0440\u0435\u0439 (Roads of Emperors)",
                                 "url": "http://magazines.russ.ru/ural/2004/10/mar11.html",
                                 "journal": "\u0423\u0440\u0430\u043b",
                                 "author": "Margovenko, A",
                                 "volume": "10",
                                 "year": "2004"
                                 },
                                template_name='cite journal')
        self.assertEqual(p['Title'],
                         '\u0414\u043e\u0440\u043e\u0433\u0438 \u0446\u0430\u0440\u0435\u0439 (Roads of Emperors)')

    def test_mwtext(self):
        # taken from https://en.wikipedia.org/wiki/Joachim_Lambek
        import mwparserfromhell
        mwtext = """
        ===Articles===
        * {{Citation | last1=Lambek | first1=Joachim | author1-link=Joachim Lambek | last2=Moser | first2=L. | title=Inverse and Complementary Sequences of Natural Numbers| doi=10.2307/2308078 | mr=0062777  | journal=[[American Mathematical Monthly|The American Mathematical Monthly]] | issn=0002-9890 | volume=61 | issue=7 | pages=454–458 | year=1954 | jstor=2308078 | publisher=The American Mathematical Monthly, Vol. 61, No. 7}}
        * {{Citation | last1=Lambek | first1=J. | author1-link=Joachim Lambek | title=The Mathematics of Sentence Structure | year=1958 | journal=[[American Mathematical Monthly|The American Mathematical Monthly]] | issn=0002-9890 | volume=65 | pages=154–170 | doi=10.2307/2310058 | issue=3 | publisher=The American Mathematical Monthly, Vol. 65, No. 3 | jstor=1480361}}
        *{{Citation | last1=Lambek | first1=Joachim | author1-link=Joachim Lambek | title=Bicommutators of nice injectives | doi=10.1016/0021-8693(72)90034-8 | mr=0301052  | year=1972 | journal=Journal of Algebra | issn=0021-8693 | volume=21 | pages=60–73}}
        *{{Citation | last1=Lambek | first1=Joachim | author1-link=Joachim Lambek | title=Localization and completion | doi=10.1016/0022-4049(72)90011-4 | mr=0320047  | year=1972 | journal=Journal of Pure and Applied Algebra | issn=0022-4049 | volume=2 | pages=343–370 | issue=4}}
        *{{Citation | last1=Lambek | first1=Joachim | author1-link=Joachim Lambek | title=A mathematician looks at Latin conjugation | mr=589163  | year=1979 | journal=Theoretical Linguistics | issn=0301-4428 | volume=6 | issue=2 | pages=221–234 | doi=10.1515/thli.1979.6.1-3.221}}

        """
        wikicode = mwparserfromhell.parse(mwtext)
        for tpl in wikicode.filter_templates():
            parsed = parse_citation_template(tpl, 'en')
            print parsed
            # All templates in this example are citation templates
            self.assertIsInstance(parsed, dict)


if __name__ == '__main__':
        unittest.main()
