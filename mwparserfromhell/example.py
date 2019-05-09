mwtext = """
{{Infobox settlement
|official_name =Mohammadabad
|native_name =
|settlement_type        = village
|pushpin_map            =Iran
|mapsize                =150px
|subdivision_type       = [[List of countries|Country]]
|subdivision_name = {{flag|Iran}}
|subdivision_type1 =[[Provinces of Iran|Province]]
|subdivision_name1 =[[Sistan and Baluchestan Province|Sistan and Baluchestan]]
|subdivision_type2 =[[Counties of Iran|County]]
|subdivision_name2 = [[Khash County|Khash]]
|subdivision_type3 =[[Bakhsh]]
|subdivision_name3 =[[Nukabad District|Nukabad]]
|subdivision_type4 =[[Rural Districts of Iran|Rural District]]
|subdivision_name4 =[[Eskelabad Rural District|Eskelabad]]
|leader_title           = 
|leader_name            = 
|established_title      =
|established_date       = 
|area_total_km2           = 
|area_footnotes           = 
|population_as_of         = 2006
|population_total =69
|population_density_km2   =auto
|timezone               = [[Iran Standard Time|IRST]]
|utc_offset             = +3:30
|timezone_DST           = [[Iran Daylight Time|IRDT]]
|utc_offset_DST         = +4:30
|coordinates            = {{coord|28|41|32|N|60|34|17|E|region:IR|display=inline,title}}
|elevation_m            = 
|area_code              = 
|website                = 
|footnotes              =
}}
'''Mohammadabad''' ({{lang-fa|farsi}}, also [[Romanize]]d as '''Mohammadabad''')<ref>{{GEOnet3|-3757028|Mohammadabad}}</ref> is a village in [[Eskelabad Rural District]], [[Nukabad District]], [[Khash County]], [[Sistan and Baluchestan Province]], [[Iran]]. At the 2006 census, its population was 69, in 13 families.<ref>{{IranCensus2006|11}}</ref>

== References ==
{{reflist}}

{{Khash County}}

{{Portal|Iran}}

{{DEFAULTSORT:Mohammadabad, Eskelabad}}
[[Category:Populated places in Khash County]]

{{Khash-geo-stub}}
"""

import mwparserfromhell
from wikiciteparser.parser import parse_citation_template

wikicode = mwparserfromhell.parse(mwtext)
templates = wikicode.filter_templates()

for tpl, section, neighboring, tags in templates:
    parsed = parse_citation_template(tpl)
    if parsed:
        print(parsed)
        print('\nSection: {}'.format(section))
        print('\nNeighboring: {}'.format(neighboring))
        print('\nTags: {}'.format(tags))