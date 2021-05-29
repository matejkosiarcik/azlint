#!/usr/bin/env python3

# List all files in a given project (either git repository or bare directory)

from __future__ import absolute_import, division, print_function, unicode_literals

import argparse
import itertools
import pathlib
import re
import subprocess
import sys
from os import path
from typing import Iterable, List, Optional


def main(argv: Optional[List[str]]) -> int:
    if argv is None:
        argv = sys.argv[1:]

    parser = argparse.ArgumentParser()
    parser.add_argument("--only-changed", action="store_true")
    args = parser.parse_args(argv)

    for file in find_files(args.only_changed):
        print(file)
    return 0


# Get list of files to lint in current directory based on globbing desired filepaths
def find_files(only_changed: bool) -> Iterable[str]:
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

            if commit is None:
                print("Could not get parent branch, returning all files", sys.stderr)
            else:
                added_staged_files = {
                    x
                    for x in subprocess.check_output(["git", "diff", "--name-only", "--cached", "--diff-filter=A", "-z"]).decode("utf-8").split("\0")
                    if len(x) > 0
                }

                # actually this might not always be right
                # sometimes when getting changes for old branch, HEAD might be too far ahead and so return unnecessary results
                # however it should be right 99% of the time, good enough for this little tool ¯\_(ツ)_/¯
                changed_files = {
                    x
                    for x in subprocess.check_output(["git", "whatchanged", "--name-only", "--pretty=", f"{commit}..HEAD", "-z"])
                    .decode("utf-8")
                    .split("\0")
                    if len(x) > 0
                }
                files = [x for x in files if x in set.union(changed_files, added_staged_files)]

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
