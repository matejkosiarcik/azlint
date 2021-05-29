#!/usr/bin/env python3

from __future__ import absolute_import, division, print_function, unicode_literals

import argparse
import re
import sys
from typing import Iterable, List


def match_file(file: str, regexes: Iterable[re.Pattern]) -> bool:
    for regex in regexes:
        if re.match(regex, file):
            return True
    return False


# Transform wildcard to regex
# This might not be foolproof, but should be ok for most uses
# Handles even relatively complex things like '*.{c,h}{,pp}'
def wildcard2regex(pattern: str) -> re.Pattern:
    pattern = re.sub(r"\.", "\\.", pattern)
    pattern = re.sub(r"\?", ".", pattern)
    pattern = re.sub(r"\*", ".*", pattern)
    pattern = re.sub(r"{", "(", pattern)
    pattern = re.sub(r"}", ")", pattern)
    pattern = re.sub(r",", "|", pattern)
    return re.compile(f"^(.*/)?{pattern}$")


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("list", type=str)
    parser.add_argument("patterns", nargs="*", default=["*"])
    args = parser.parse_args(argv)

    regexes = [wildcard2regex(x) for x in args.patterns]
    with open(args.list) as file_list:
        for file in file_list:
            file = file.rstrip()
            if match_file(file, regexes):
                print(file)

    return 0


if __name__ == "__main__":
    main(sys.argv[1:])
