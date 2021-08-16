#!/usr/bin/env python3
"""Get changelog from the MR's description."""
import argparse
import logging
import os
import re
import sys

import requests
import fw_logging

fw_logging.setup_logging(handler="stderr")
log = logging.getLogger(__name__)


def main(args=None):
    """Get changelog."""
    parser = argparse.ArgumentParser(
        description="Get changelog from the MR's description"
    )
    parser.add_argument(
        "-f",
        "--full",
        action="store_true",
        help="Return the full description",
    )
    args = parser.parse_args(args)

    commit_message = os.environ.get("CI_COMMIT_MESSAGE")
    if not commit_message:
        print("'CI_COMMIT_MESSAGE' is empty")
        sys.exit(1)

    mr_id = re.search(r"!([0-9]+)", commit_message)
    if not mr_id:
        log.error(f"Could not find MR ID in {commit_message}")
        sys.exit(1)

    with requests.Session() as sess:
        url = (
            f"{os.environ.get('CI_API_V4_URL')}/projects/"
            f"{os.environ.get('CI_PROJECT_ID')}/merge_requests?"
            f"iids[]={mr_id}"
        )
        headers = {
            "Content-Type": "application/json",
            "Private-Token": os.environ.get("GITLAB_CI_BOT_TOKEN"),
        }

        resp = sess.get(url, allow_redirects=True, timeout=10, headers=headers)
        if not resp.ok:
            log.error(f"Response is not successful: {resp.content}")
            sys.exit(1)
        description = resp.json()[0]["description"]
        if args.full:
            print(description)
            return

        description_body = re.match(r"(.*)\*{3,}", description, re.S)
        if not description_body:
            print(description)
            return
        print(description_body.groups()[0].strip())


if __name__ == "__main__":  # pragma: no cover
    main()
