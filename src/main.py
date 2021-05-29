#!/usr/bin/env python3

from __future__ import absolute_import, division, print_function, unicode_literals

import argparse
import functools
import subprocess
import sys
import tempfile
from os import path
from typing import List, Optional


def main(argv: Optional[List[str]]) -> int:
    parser = argparse.ArgumentParser()
    parser.prog = "azlint"
    parser.add_argument("-V", "--version", action="version", version="%(prog)s 0.4.1")
    parser.add_argument("-c", "--only-changed", action="store_true", help="Analyze only changed files (on current git branch)")
    subparsers = parser.add_subparsers(dest="command")
    lint_parser = subparsers.add_parser("lint", help="Lint files (default)")
    lint_parser.add_argument("-c", "--only-changed", action="store_true", default=argparse.SUPPRESS)
    fmt_parser = subparsers.add_parser("fmt", help="Fix files")
    fmt_parser.add_argument("-c", "--only-changed", action="store_true", default=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.command == "lint" or args.command == "fmt":
        command = args.command
    elif args.command is None:
        command = "lint"
    else:
        print(f"Unknown command {args.command}", file=sys.stderr)
        sys.exit(1)

    # because other files are in the same directory
    script_dirname = path.dirname(path.realpath(__file__))

    # find files to validate
    find_command = [path.join(script_dirname, "list_files.py")]
    if args.only_changed:
        find_command.append("--only-changed")
    filelist = tempfile.mktemp()
    with open(filelist, "w") as file:
        subprocess.check_call(find_command, stdout=file)

    with open(filelist, "r") as file:
        line_count = functools.reduce(lambda x, sum: x + sum, (1 for _ in file), 0)
        if line_count == 0:
            print("No files found", file=sys.stderr)
            sys.exit(0)

    # actually perform linting/formatting
    run_command = [path.join(script_dirname, "run.sh"), command, filelist]
    try:
        subprocess.check_call(run_command)
    except subprocess.CalledProcessError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
    return 0


if __name__ == "__main__":
    main(sys.argv[1:])
