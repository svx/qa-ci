#!/usr/bin/env python3
"""Get FW_RELEASE_BRANCH and FW_RELEASE_COMMIT details."""
import argparse
import os
import re

import requests

INFRA_REPO = "flywheel-io%2Finfrastructure%2Frelease"

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
    if not commit_message:
        print("No FW_RELEASE_COMPONENT set, exiting")
        sys.exit(0)

    with requests.Session() as sess:
        url = (
            f"{os.environ.get('CI_API_V4_URL')}/projects/"
            f"{INFRA_REPO}/merge_requests?"
            "state=opened&target_branch=master"
        )
        headers = {
            'Content-Type': 'application/json',
            'Private-Toke': os.environ.get("GITLAB_CI_BOT_TOKEN")
        }

        resp = sess.get(url, allow_redirects=True, timeout=10, headers=headers)
        if not resp.ok:
            print(f"Response is not successful: {resp.content}")
            sys.exit(1)

        if len(resp.json()) < 1:
            print(f"No open MR found in {INFRA_REPO} repository.")
            sys.exit(0)

        fw_release_branch=resp.json()[0]["source_branch"]
        fw_release_commit=f"fix: update {component} version to {args.version}"

        print(f">>>\nFW_RELEASE_BRANCH=\"{fw_release_branch}\"\nFW_RELEASE_COMMIT=\"{fw_release_commit}\"\n>>>")

if __name__ == "__main__":
    main()
