wikiciteparser
==============

This Python library wraps Wikipedia's citation processing code (written
in Lua) to parse citation templates. For instance, there are many
different ways to specify the authors of a citation: this codes maps all
of them to the same representation.

Distributed under the MIT license.

Dependencies: lupa, mwparserfromhell

Example
-------

Let's parse the reference section of `this
article <https://en.wikipedia.org/wiki/Joachim_Lambek>`__::

    import mwparserfromhell
    from wikiciteparser.parser import parse_citation_template

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
       parsed = parse_citation_template(tpl)
       print parsed

Here is what you get::

    {u'PublisherName': u'The American Mathematical Monthly, Vol. 61, No. 7', u'Title': u'Inverse and Complementary Sequences of Natural Numbers', u'ID_list': {u'DOI': u'10.2307/2308078', u'ISSN': u'0002-9890', u'MR': u'0062777', u'JSTOR': u'2308078'}, u'Periodical': u'The American Mathematical Monthly', u'Authors': [{u'link': u'Joachim Lambek', u'last': u'Lambek', u'first': u'Joachim'}, {u'last': u'Moser', u'first': u'L.'}], u'Date': u'1954', u'Pages': u'454-458'}
    {u'PublisherName': u'The American Mathematical Monthly, Vol. 65, No. 3', u'Title': u'The Mathematics of Sentence Structure', u'ID_list': {u'DOI': u'10.2307/2310058', u'ISSN': u'0002-9890', u'JSTOR': u'1480361'}, u'Periodical': u'The American Mathematical Monthly', u'Authors': [{u'link': u'Joachim Lambek', u'last': u'Lambek', u'first': u'J.'}], u'Date': u'1958', u'Pages': u'154-170'}
    {u'Title': u'Bicommutators of nice injectives', u'ID_list': {u'DOI': u'10.1016/0021-8693(72)90034-8', u'ISSN': u'0021-8693', u'MR': u'0301052'}, u'Periodical': u'Journal of Algebra', u'Authors': [{u'link': u'Joachim Lambek', u'last': u'Lambek', u'first': u'Joachim'}], u'Date': u'1972', u'Pages': u'60-73'}
    {u'Title': u'Localization and completion', u'ID_list': {u'DOI': u'10.1016/0022-4049(72)90011-4', u'ISSN': u'0022-4049', u'MR': u'0320047'}, u'Periodical': u'Journal of Pure and Applied Algebra', u'Authors': [{u'link': u'Joachim Lambek', u'last': u'Lambek', u'first': u'Joachim'}], u'Date': u'1972', u'Pages': u'343-370'}
    {u'Title': u'A mathematician looks at Latin conjugation', u'ID_list': {u'DOI': u'10.1515/thli.1979.6.1-3.221', u'ISSN': u'0301-4428', u'MR': u'589163'}, u'Periodical': u'Theoretical Linguistics', u'Authors': [{u'link': u'Joachim Lambek', u'last': u'Lambek', u'first': u'Joachim'}], u'Date': u'1979', u'Pages': u'221-234'}

