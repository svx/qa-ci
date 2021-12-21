#!/usr/bin/env bash

test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 RELEASE_BRANCH RELEASE_COMMIT

Update infra release MR with component's tag.
"

# shellcheck disable=SC1091
. /ci/utils.sh

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test $# -eq 2 || { echo "Missing required arguments."; echo "$USAGE"; exit 1; }
    RELEASE_BRANCH=$1 && shift
    RELEASE_COMMIT=$1 && shift
    cd "$(git_clone "$RELEASE_REPO" --branch "$RELEASE_BRANCH")"
    sed -Ei "s/(RELEASECI_${RELEASE_COMPONENT}_VERSION: ).*/\1$CI_COMMIT_TAG/I" .gitlab-ci.yml
    git --no-pager diff -U0 --word-diff=color --exit-code && { echo "Nothing to commit"; exit 1; }
    git commit -am "$RELEASE_COMMIT"
    git push origin "$RELEASE_BRANCH"
}

main "$@"
