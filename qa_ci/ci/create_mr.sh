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
https://docs.gitlab.com/ee/user/project/push_options.html#push-options-for-merge-requests
"

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test $# -ge 2 || { echo "Missing required BRANCH/TARGET."; echo "$USAGE"; exit 1; }
    git --no-pager diff -U0 --word-diff=color --exit-code && { echo "Nothing to commit"; exit; }
    BRANCH=$1 && shift
    TARGET=$1 && shift
    MR_OPTS=(
        -omerge_request.create
        -omerge_request.target="$TARGET"
        -omerge_request.remove_source_branch
    )
    for MR_OPT in "$@"; do MR_OPTS+=(-omerge_request."$MR_OPT"); done
    git checkout -B "$BRANCH"
    git commit -am "$BRANCH"
    git push -f origin "$BRANCH" "${MR_OPTS[@]}"
}

main "$@"
