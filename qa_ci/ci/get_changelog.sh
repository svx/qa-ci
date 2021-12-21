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
    echo -e "[//]: # (CHANGELOG START)\n"
    REV1=${1:-$(git describe --abbrev=0 --tags || true)}
    REV2=${2:-HEAD}
    REVS=$(git log --merges --grep="See merge request" --format="%h" "$REV1..$REV2")
    test -z "$REVS" || echo -e "#### MR Changelog\n"
    for REV in $REVS; do
        LOG=$(git show --format="%b" "$REV")
        MR_NO=$(echo "$LOG" | grep "See merge request" | grep -Eo '![0-9]+')
        MR_TITLE=$(echo "$LOG" | head -n1 | sed -E 's/\[FLYW-[0-9]+\]//g')
        echo "- $MR_NO $MR_TITLE" | sed -E 's/[ ]{2,}/ /g'
        TICKETS+="$(echo "$LOG" | grep -Eo 'FLYW-[0-9]+' || true)"
        TICKETS+=$'\n'
    done
    TICKETS="$(echo "${TICKETS:-}" | grep -Ev 'FLYW-0+|^$' | sort -u | sort -nr || true)"
    if test -n "${TICKETS:-}"; then
        TICKETS=$(echo "$TICKETS" | awk '{print "- " $0}')
        echo -e "\n\n#### JIRA tickets\n\n$TICKETS"
    fi
    echo -e "\n[//]: # (CHANGELOG END)\n"
}

main "$@"
