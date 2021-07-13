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
        ISSUE_NUMBERS=()
        for ISSUE in $(echo "$MR_TITLE" | grep -Eo "\[\s*FLYW-[0-9]+\s*\]"); do
            if $(echo "$ISSUE" | grep -Eq "FLYW-[0-9]+"); then
                ISSUE=$(echo "$ISSUE" | grep -Eo "[0-9]+")
                if [[ ! "${ISSUE_NUMBERS[@]}" =~ "${ISSUE}" ]]; then
                    # add once
                    ISSUE_NUMBERS+=("${ISSUE}")
                fi
            fi
        done
        if [ ${#ISSUE_NUMBERS[@]} -ne 0 ]; then
            # sort as numbers
            ISSUE_NUMBERS=$(IFS=$'\n'; echo "${ISSUE_NUMBERS[*]}" | sort -n)
            ISSUE_STR=$(printf "[FLYW-%d], " "${ISSUE_NUMBERS[@]}")
            echo "    - ${ISSUE_STR::-2}"
        fi
    done
}

main "$@"
