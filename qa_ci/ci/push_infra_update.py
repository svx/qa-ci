#!/usr/bin/env python3
"""Update the infrastructure/release repository."""
import argparse
import os
import re

import requests

from qa_ci.ci.get_changelog_from_mr import main as mr_chlog_main

INFRA_REPO = "git@gitlab.com:flywheel-io/infrastructure/release.git"


def replace(file, search, replace):
    """Replace content in file."""
    content = ""
    with open(file) as fp:
        content = fp.read()
    content = re.sub(search, replace, content)
    with open(file, "w") as fp:
        fp.write(content)


def main(args=None):  # pragma: no cover
    """Get changelog."""
    parser = argparse.ArgumentParser(
        description="Update the infrastructure/release repository"
    )
    parser.add_argument(
        "version",
        metavar="FW_RELEASE_VERSION",
        type=str,
        help="Release version",
    )
    args = parser.parse_args(args)

    component = os.environ.get("FW_RELEASE_COMPONENT")
    if not component:
        print("No FW_RELEASE_COMPONENT set, exiting")
        sys.exit(1)

    commit_message = mr_chlog_main(["--full"])
    match = re.match(
        r"FW_RELEASE_BRANCH=\"(.*)\"\s*FW_RELEASE_COMMIT=\"(.*)\"", commit_message
    )
    if not match:
        print("Could not extract FW_RELEASE_BRANCH and FW_RELEASE_COMMIT, exiting")
        return

    fw_release_branch = match.grpups()[0]
    fw_release_commit = match.grpups()[1]

    repo = git.repo.Repo("./release_repo")
    repo.clone_from(INFRA_REPO)
    repo.git.checkout(fw_release_branch)

    replace(
        "./release_repo/.gitlab-ci.yml" f"RELEASECI_{component}_VERSION:.*",
        f"RELEASECI_{component}_VERSION: {args.version}",
    )

    repo.git.commit("-am", fw_release_commit)
    origin = repo.remote(name="origin")
    origin.push()


if __name__ == "__main__":  # pragma: no cover
    main()
