#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 RELEASE_VERSION

Get FW_RELEASE_BRANCH and FW_RELEASE_COMMIT details
"

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }

    if [ -z ${FW_RELEASE_COMPONENT+x} ]; then
        # no component set, exit
        exit 0
    fi

    RELEASE_VERSION=$1 && shift
    INFRA_REPOSITORY="infrastructure%2Frelease"
    RESPONSE=$(curl -fLSs "$CI_API_V4_URL/projects/$INFRA_REPOSITORY/merge_requests?state=open&target_branch=master" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json")
    MR_CNT=$(echo "$RESPONSE" | jq length)
    if [[ $MR_CNT -lt 1 ]]
    then
        echo "No open MR found in ${INFRA_REPOSITORY} repository."; exit 0;
    fi

    FW_RELEASE_BRANCH=$(echo "$RESPONSE" | jq -r '.[0].source_branch')
    FW_RELEASE_COMMIT="fix: update ${FW_RELEASE_COMPONENT} version to ${RELEASE_VERSION}"

    echo ">>>"
    echo "FW_RELEASE_BRANCH=\"${FW_RELEASE_BRANCH}\""
    echo "FW_RELEASE_COMMIT=\"${FW_RELEASE_COMMIT}\""
    echo ">>>"
}

main "$@"
