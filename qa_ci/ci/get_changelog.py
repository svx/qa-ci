#!/usr/bin/env python3

import argparse
import os

import git

def main():
    parser = argparse.ArgumentParser(description="Generate a changelog (markdown) from the merge commits found in a revision range.")
    parser.add_argument('rev1', metavar='REV1', type=str, nargs='?', help='Start revision (default: last tag)')
    parser.add_argument('rev2', metavar='REV2', type=str, nargs='?', help='End revision (default: HEAD)')

    args = parser.parse_args()
    rev1 = args.rev1
    rev2 = args.rev2

    repo = git.repo.Repo('./')
    if not rev1:
        try:
            rev1 = repo.git.describe(abbrev=0, tags=True)
        except git.exc.GitCommandError:
            rev1 = ""
        print(rev1)
    if not rev2:
        rev2 ="HEAD"
        print(rev2)

    revs = repo.git.log(f"{rev1}..{rev2}", merges=True, format="%h")


    print(revs)


#  REVS=$(git log --merges --format="%h" "$REV1..$REV2")

# REV1=${1:-$(git describe --abbrev=0 --tags || true)}






if __name__ == "__main__":
    main()
