#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 CI_COMMIT_MESSAGE

Get changelog from the MR's description.
The MR ID is extracted from the commit message.
"

main() {
    CI_COMMIT_MESSAGE=$1 && shift
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    MR_ID_REGEX="!([0-9]+)"
    if [[ $CI_COMMIT_MESSAGE =~ $MR_ID_REGEX ]]
    then
        MR_IID="${BASH_REMATCH[1]}"
    else
        echo "Could not find MR ID in $CI_COMMIT_MESSAGE"; exit 1;
    fi
    echo "$MR_IID"

    RESPONSE=$(curl -fLSs "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests?iids[]=$MR_IID" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json")
    MR_CNT=$(echo "$RESPONSE" | jq length)
    if [[ $MR_CNT != 1 ]]
    then
        echo "MR was not found with ID $MR_IID. Response: $RESPONSE"; exit 1;
    fi
    DESCRIPTION=$(echo "$RESPONSE" | jq -r '.[0].description')
    echo "$DESCRIPTION"
}

main "$@"
