#!/bin/env python
# Random Country Selector
# 2014/01/26
import os
import random
import subprocess
from urllib.parse import quote

# load country list
filepath = os.path.expanduser('~/Dropbox/Documents/countries.txt')
countries = [x.strip() for x in open(filepath).readlines()]

# choose random country
country = random.sample(countries, 1).pop()
print("Opening Wikipedia page for %s" % country)

# generate link to Wikipedia
url = "http://en.wikipedia.org/wiki/%s" % quote(country)

# open in browser
command = ['chromium', url]

with open(os.devnull, "w") as fnull:
    result = subprocess.call(command, stdout=fnull, stderr=fnull)

