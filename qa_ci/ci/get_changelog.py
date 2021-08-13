#!/usr/bin/env python3
"""Get MARKDOWN style changelog."""

import argparse
import os
import re

import git


def main(args=None):
    """Get changelog."""
    parser = argparse.ArgumentParser(
        description="Generate a changelog (markdown) from the merge commits found in a revision range."
    )
    parser.add_argument(
        "rev1",
        metavar="REV1",
        type=str,
        nargs="?",
        help="Start revision (default: last tag)",
    )
    parser.add_argument(
        "rev2", metavar="REV2", type=str, nargs="?", help="End revision (default: HEAD)"
    )

    args = parser.parse_args(args)
    rev1 = args.rev1
    rev2 = args.rev2

    repo = git.repo.Repo("./")
    if not rev1:
        rev1 = repo.git.describe(abbrev=0, tags=True)
    if not rev2:
        rev2 = "HEAD"

    revs = repo.git.log(f"{rev1}..{rev2}", merges=True, format="%h")
    merge_req_data = {}
    for rev in iter(revs.splitlines()):
        log = repo.git.show(rev, format="%b")
        mr_no = re.search(r"See merge request.*(![\d]+)", log)
        if mr_no:
            mr_no = mr_no.groups()[0]
        else:
            mr_no = ""
        issue_numbers = set()
        for match in re.finditer(r"\[\s*(FLYW)\s*-\s*([\d]+)\s*\]", log, re.IGNORECASE):
            issue_numbers.add(f"{match.groups()[0]}-{match.groups()[1]}")

        print(f"- {mr_no} {log.splitlines()[0]}")
        if issue_numbers:
            print("    - " + " ".join(sorted(issue_numbers)))


if __name__ == "__main__":  # pragma: no cover
    main()
