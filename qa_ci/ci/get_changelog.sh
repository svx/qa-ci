#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 [REV1] [REV2]

Generate a changelog (markdown) from the merge commits found in a revision range.
By default, the range starts from the last tag and ends with the HEAD revision.
"

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    REV1=${1:-$(git describe --abbrev=0 --tags || true)}
    REV2=${2:-HEAD}
    REVS=$(git log --merges --format="%h" "$REV1..$REV2")
    for REV in $REVS; do
        LOG=$(git show --format="%b" "$REV")
        MR_NO=$(echo "$LOG" | grep "See merge request" | grep -Eo '![0-9]+')
        MR_TITLE=$(echo "$LOG" | head -n1)
        echo "- $MR_NO $MR_TITLE"
    done
}

main "$@"
