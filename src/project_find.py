#!/usr/bin/env python3

# This files accepts list of globs to search in current directory
# It does (by design) not need any 3rd party dependencies
# Supports searching in raw directories and git repositories

from __future__ import absolute_import, division, print_function, unicode_literals

import argparse
import itertools
import os
import pathlib
import subprocess
import sys
from typing import Iterable, List, Optional


# Main function
def main(argv: Optional[List[str]]) -> int:
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "patterns", nargs="*", default=["*"], help="Glob patterns to find"
    )
    parser.prog = "project_find"
    args = parser.parse_args(argv)

    for file in find_files(args.patterns):
        print(file)
    return 0


# Get list of files to lint in current directory based on globbing desired filepaths
# TODO: add support for ignoring files
def find_files(patterns: List[str]) -> Iterable[str]:
    globs = ["*"] if len(patterns) == 0 else patterns

    # check if we are currently in git repository
    is_git = False
    try:
        # this command returns code 0 in repository, otherwise non-0
        subprocess.check_call(
            ["git", "rev-parse", "--git-dir"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        is_git = True
    except subprocess.CalledProcessError:
        pass
    # print('Is git:', is_git, file=sys.stderr)

    if is_git:
        # NOTE: `git ls-files` accepts kinda non-standard globs
        # `git ls-files *.js` does not glob *files* with a name of "*.json", it globs *PATHS* with pattern of "*.json"
        # So if we glob literal name of certain files, such as "package.json":
        # `git ls-files package.json` -> this will only find package.json in the root of the repository
        # `git ls-files */package.json` -> this will find package.json anywhere except the root of the repository
        # `git ls-files package.json */package.json` -> this will find it anywhere, which we want
        globs = ([f"*/{x}", x] for x in globs)
        globs = list(itertools.chain(*globs))

        tracked_files = (
            subprocess.check_output(["git", "ls-files", "-z"] + globs)
            .decode("utf-8")
            .split("\0")
        )
        tracked_files = [x for x in tracked_files if len(x) > 0]
        # print('tracked:', tracked_files, file=sys.stderr)

        deleted_files = (
            subprocess.check_output(["git", "ls-files", "-z", "--deleted"] + globs)
            .decode("utf-8")
            .split("\0")
        )
        deleted_files = {x for x in deleted_files if len(x) > 0}
        # print('deleted:', deleted_files, file=sys.stderr)

        untracked_files = (
            subprocess.check_output(
                ["git", "ls-files", "-z", "--others", "--exclude-standard"] + globs
            )
            .decode("utf-8")
            .split("\0")
        )
        untracked_files = [x for x in untracked_files if len(x) > 0]
        # print('untracked:', untracked_files, file=sys.stderr)

        all_files = [
            x for x in tracked_files if x not in deleted_files
        ] + untracked_files
        return sorted(all_files)
    else:
        # we want recursive glob, anywhere under current directory
        globs = (f"**/{x}" for x in globs)

        all_files = []
        for pattern in globs:
            # all_files += glob.iglob(pattern, recursive=True)
            # use pathlib instead of glob, because it also returns hidden files
            all_files += [str(x) for x in pathlib.Path(".").glob(pattern)]

        # I guess limit results to actual files
        all_files = [
            x
            for x in all_files
            if os.path.isfile(x) or os.path.isfile(os.path.realpath(x))
        ]
        return sorted(all_files)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
