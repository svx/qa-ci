#!/usr/bin/env python3
"""Get FW_RELEASE_BRANCH and FW_RELEASE_COMMIT details."""
import argparse
import logging
import os
import re
import sys

import requests
import fw_logging

INFRA_REPO = "flywheel-io%2Finfrastructure%2Frelease"

fw_logging.setup_logging(handler="stderr")
log = logging.getLogger(__name__)


def main(args=None):
    """Get changelog."""
    parser = argparse.ArgumentParser(
        description="Get FW_RELEASE_BRANCH and FW_RELEASE_COMMIT details"
    )
    parser.add_argument(
        "version",
        metavar="RELEASE_VERSION",
        type=str,
        help="Release version",
    )
    args = parser.parse_args(args)

    component = os.environ.get("FW_RELEASE_COMPONENT")
    if not component:
        log.warning("No FW_RELEASE_COMPONENT set, exiting")
        return

    with requests.Session() as sess:
        url = (
            f"{os.environ.get('CI_API_V4_URL')}/projects/"
            f"{INFRA_REPO}/merge_requests?"
            "state=opened&target_branch=master"
        )
        headers = {
            "Content-Type": "application/json",
            "Private-Token": os.environ.get("GITLAB_CI_BOT_TOKEN"),
        }

        resp = sess.get(url, allow_redirects=True, timeout=10, headers=headers)
        if not resp.ok:
            log.error(f"Response is not successful: {resp.content}")
            sys.exit(1)

        fw_release_commit = f"fix: update {component} version to {args.version}"

        if len(resp.json()) < 1:
            log.warning(f"No open MR found in {INFRA_REPO} repository.")
            fw_release_branch = ""
        else:
            fw_release_branch = resp.json()[0]["source_branch"]

        print(
            f'>>>\nFW_RELEASE_BRANCH="{fw_release_branch}"\nFW_RELEASE_COMMIT="{fw_release_commit}"\n>>>'
        )


if __name__ == "__main__":  # pragma: no cover
    main()
