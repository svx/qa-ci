#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 VERSION

Print FW_RELEASE_BRANCH and FW_RELEASE_COMMIT details
"

main() {
    ${INFRA_REPOSITORY:=infrastructure%2Frelease}
    VERSION=$1
    RESPONSE=$(curl -fLSs "$CI_API_V4_URL/projects/$INFRA_REPOSITORY/merge_requests?state=open&target_branch=master" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json")
    MR_CNT=$(echo "$RESPONSE" | jq length)
    if [[ $MR_CNT < 1 ]]
    then
        echo "No open MR found in ${INFRA_REPOSITORY} repository."; exit 1;
    fi

    FW_RELEASE_BRANCH=$(echo "$RESPONSE" | jq -r '.[0].source_branch')
    FW_RELEASE_COMMIT=$(echo "fix: update ${FW_RELEASE_COMPONENT} version to ${VERSION}")










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
            ISSUE_NUMBERS=( $(IFS=$'\n'; echo "${ISSUE_NUMBERS[*]}" | sort -n) )
            ISSUE_STR=$( printf "[FLYW-%d], " "${ISSUE_NUMBERS[@]}")
            echo "    - ${ISSUE_STR::-2}"
        fi
    done
}

array_contains () {
    local SEEKING=$1; shift
    local IN=1
    for ELEMENT; do
        if [[ $ELEMENT == "$SEEKING" ]]; then
            IN=0
            break
        fi
    done
    return $IN
}

main "$@"
