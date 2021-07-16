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
https://docs.gitlab.com/ee/api/merge_requests.html#create-mr
"

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test $# -ge 2 || { echo "Missing required BRANCH/TARGET."; echo "$USAGE"; exit 1; }
    git --no-pager diff -U0 --word-diff=color --exit-code && { echo "Nothing to commit"; exit; }
    BRANCH=$1 && shift
    TARGET=$2 && shift
    git checkout -B "$BRANCH"
    git commit -am "$BRANCH"
    git push -f origin "$BRANCH"

    declare -A MR_OPTS
    MR_OPTS["title"]=$BRANCH

    OPT_REGEX="^([^=]+)=(.*)$"
    for MR_OPT in "$@"; do
        if [[ $MR_OPT =~ $OPT_REGEX ]]; then
            MR_OPTS[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
        else
            echo "Invalid key-value '$MR_OPT', skipping";
        fi
    done

    # make sure these options are not editable
    MR_OPTS["id"]=$CI_PROJECT_ID
    MR_OPTS["source_branch"]=$BRANCH
    MR_OPTS["target_branch"]=$TARGET

    jq_args=( )
    jq_query='.'
    idx=0
    for x in "${!MR_OPTS[@]}"; do
        jq_args+=( --arg "key$idx"   "$x"   )
        jq_args+=( --arg "value$idx" "${MR_OPTS[$x]}" )
        jq_query+=" | .[\$key${idx}]=\$value${idx}"
        idx+=1
    done
    PAYLOAD=$(jq "${jq_args[@]}" "$jq_query" <<<'{}')

    echo "MR creation payload: $PAYLOAD"

    curl -fLSs "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests" \
        -H "Private-Token: $GITLAB_CI_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD"
}

main "$@"
