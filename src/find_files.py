#!/usr/bin/env python3

from __future__ import absolute_import, division, print_function, unicode_literals

import argparse
import itertools
import pathlib
import re
import subprocess
import sys
import tempfile
from os import path
from typing import List, Optional


def main(argv: Optional[List[str]]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only-changed", action="store_true")
    args = parser.parse_args(argv)

    only_changed = args.only_changed is True

    for file in find_files(only_changed):
        print(file)


# Get list of all project files in current directory
def find_files(only_changed: bool) -> List[str]:
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

    if is_git:
        # NOTE: `git ls-files` accepts kinda non-standard globs
        # `git ls-files *.js` does not glob *files* with a name of "*.json", it globs *PATHS* with pattern of "*.json"
        # So if we glob literal name of certain files, such as "package.json":
        # `git ls-files package.json` -> this will only find package.json in the root of the repository
        # `git ls-files */package.json` -> this will find package.json anywhere except the root of the repository
        # `git ls-files package.json */package.json` -> this will find it anywhere, which we want

        tracked_files = [x for x in subprocess.check_output(["git", "ls-files", "-z"]).decode("utf-8").split("\0") if len(x) > 0]

        deleted_files = {x for x in subprocess.check_output(["git", "ls-files", "-z", "--deleted"]).decode("utf-8").split("\0") if len(x) > 0}

        files = [x for x in tracked_files if x not in deleted_files]

        # filter only recent changes when requested
        if only_changed:
            current_branches = [
                re.sub(r"^\* ", "", x)
                for x in subprocess.check_output(["git", "branch", "--list"]).decode("utf-8").strip().split("\n")
                if re.match(r"^\* .+$", x)
            ]
            assert len(current_branches) == 1, "Too many current branches"
            current_branch = current_branches[0]

            commit = None
            for i in itertools.count(start=0):
                try:
                    commit_branches = [
                        x
                        for x in subprocess.check_output(["git", "branch", "--contains", f"HEAD~{i}", "--format=%(refname:short)"])
                        .decode("utf-8")
                        .strip()
                        .split("\n")
                        if x != current_branch
                    ]
                except subprocess.CalledProcessError:
                    break

                if len(commit_branches) > 0:
                    commit = f"HEAD~{i}"
                    break

            # get files modified in working tree
            changed_files = {
                x
                for x in itertools.chain(
                    subprocess.check_output(["git", "diff", "--name-only", "--cached", "-z"]).decode("utf-8").split("\0"),
                    subprocess.check_output(["git", "diff", "--name-only", "HEAD", "-z"]).decode("utf-8").split("\0"),
                )
                if len(x) > 0
            }

            if commit is None:
                # get files modified
                print("Could not get parent branch, returning all files", sys.stderr)
            else:
                # get files modified
                changed_files = set.union(
                    changed_files,
                    {
                        x
                        for x in subprocess.check_output(["git", "whatchanged", "--name-only", "--pretty=", f"{commit}..HEAD", "-z"])
                        .decode("utf-8")
                        .split("\0")
                        if len(x) > 0
                    },
                )

            files = [x for x in files if x in changed_files]

        # untracked files are not in git whatchanged
        # but they should be in both full output and changed output as well
        untracked_files = [
            x for x in subprocess.check_output(["git", "ls-files", "-z", "--others", "--exclude-standard"]).decode("utf-8").split("\0") if len(x) > 0
        ]

        files = files + untracked_files
        return sorted(files)
    else:
        if only_changed:
            print("Could not get only changed files, not a git repository", file=sys.stderr)

        # use pathlib instead of glob, because it also returns hidden files
        # files = glob.iglob(pattern, recursive=True)
        files = [str(x) for x in pathlib.Path(".").glob("**/*") if path.isfile(x) or path.isfile(path.realpath(x))]

        return sorted(files)


if __name__ == "__main__":
    main(sys.argv[1:])
