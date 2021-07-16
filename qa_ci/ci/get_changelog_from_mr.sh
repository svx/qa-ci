#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 [COMMIT_MESSAGE] [-f]

Get changelog from the MR's description.
The MR ID is extracted from the commit message.
Only the part before the first HR is returned.
Use the -f flag to return the full description
"

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    COMMIT_MESSAGE=${1:-$CI_COMMIT_MESSAGE}
    FULL_DESCRIPTION=""
    while getopts ":f" opt; do
        case $opt in
            f)
                FULL_DESCRIPTION="true"
                ;;
            \?)
                echo "Invalid option: -$OPTARG"
                echo "$USAGE";
                exit 1
                ;;
        esac
    done
    MR_ID_REGEX="!([0-9]+)"
    if [[ $COMMIT_MESSAGE =~ $MR_ID_REGEX ]]; then
        MR_IID="${BASH_REMATCH[1]}"
    else
        echo "Could not find MR ID in $COMMIT_MESSAGE"; exit 1;
    fi
    RESPONSE=$(curl -fLSs "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests?iids[]=$MR_IID" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json")
    MR_CNT=$(echo "$RESPONSE" | jq length)
    if [[ $MR_CNT != 1 ]]; then
        echo "MR was not found with ID $MR_IID. Response: $RESPONSE"; exit 1;
    fi

    DESCRIPTION=$(echo "$RESPONSE" | jq -r '.[0].description')
    REGEX="^(.*)\*{3,}"
    if [[ $DESCRIPTION =~ $REGEX ]] && [ -z "$FULL_DESCRIPTION" ]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$DESCRIPTION"
    fi
}

main "$@"
