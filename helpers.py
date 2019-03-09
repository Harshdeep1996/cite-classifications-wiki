import re

def check_if_balanced(my_string):
    my_string = re.sub('\w|\s|[^{}]','', my_string)
    brackets = ['()', '{}', '[]'] 
    while any(x in my_string for x in brackets): 
        for br in brackets: 
            my_string = my_string.replace(br, '') 
    return not my_string
