#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 [OPTIONS...]

Get changelog from the MR's description.
One can search for the MR by specifying query params
See the list of available options below:
https://docs.gitlab.com/ee/api/merge_requests.html#list-project-merge-requests
"

main() {
    QUERY_STR=""
    OPT_REGEX="^([^=]+)=(.*)$"
    for QUERY_OPT in "$@"
    do
        if [[ $QUERY_OPT =~ $OPT_REGEX ]]
        then
            QUERY_STR="${QUERY_STR}&${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
        else
            echo "Invalid key-value '$QUERY_OPT'."; echo "$USAGE"; exit 1;
        fi
    done
    QUERY_STR="${QUERY_STR:1}"
    echo "Query string: $QUERY_STR"

    #RESPONSE=$(</tmp/sample_mr.json)
    RESPONSE=$(curl -fLSs "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests?$QUERY_STR" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json")
    MR_CNT=$(echo "$RESPONSE" | jq length)
    if [[ $MR_CNT != 1 ]]
    then
        echo "Not a single MR was found ($MR_CNT)"; exit 1;
    fi
    DESCRIPTION=$(echo "$RESPONSE" | jq -r '.[0].description')
    echo "$DESCRIPTION"
}

main "$@"
