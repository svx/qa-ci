#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 BRANCH TARGET [OPTIONS...]

Push the current diff to BRANCH and create an MR from it to the TARGET branch.
Intended for use in GitLab-CI to create MRs for automatic diffs like generated
docs and dependency updates.

Options are expected in a key=value format (eg. title='My GitLab MR Title').
See the list of available options below:
https://docs.gitlab.com/ee/api/merge_requests.html#create-mr
"

# shellcheck disable=SC1091
. /ci/utils.sh

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test $# -ge 2 || { echo "Missing required BRANCH/TARGET."; echo "$USAGE"; exit 1; }
    git --no-pager diff -U0 --word-diff=color --exit-code && { echo "Nothing to commit"; exit; }
    BRANCH=$1 && shift
    TARGET=$1 && shift
    git checkout -B "$BRANCH"
    git commit -am "$BRANCH"
    git push -f origin "$BRANCH"
    set -- "$@" source_branch="$BRANCH" target_branch="$TARGET" remove_source_branch=true
    CURL_RESP=$(curl -fLSs "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$(gjo "$@")" 2>&1
    ) || CURL_STATUS="$?"
    test -n "${CURL_STATUS:-}" || { echo "$CURL_RESP" | jq; exit; }
    echo "$CURL_RESP" | grep -vq "returned error: 409" || { echo "MR already exists"; exit; }
    err "$CURL_RESP"
    exit "$CURL_STATUS"
}

main "$@"
