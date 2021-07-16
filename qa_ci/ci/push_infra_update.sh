#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 RELEASE_VERSION

Update the infrastructure/release repository with the following changes
Update the FW_RELEASE_COMPONENT version to FW_RELEASE_VERSION
Push the changes to the FW_RELEASE_BRANCH with FW_RELEASE_COMMIT message
"

main() {
    FW_RELEASE_VERSION=$1
    if [ -z ${FW_RELEASE_COMPONENT+x} ]; then
        # no component set, exit
        echo "FW_RELEASE_COMPONENT is not set"
        echo "$USAGE";
        exit 1
    fi

    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    #COMMIT_MESSAGE="$(/ci/get_changelog_from_mr.sh -f)"
    COMMIT_MESSAGE="FW_RELEASE_BRANCH=\"2021-07-09\" FW_RELEASE_COMMIT=\"Random commit message\" FW_RELEASE_VERSION=\"16.0.0\" "

    REGEX="FW_RELEASE_BRANCH=\"(.*)\"\s*FW_RELEASE_COMMIT=\"(.*)\""
    if [[ $COMMIT_MESSAGE =~ $REGEX ]]; then
        FW_RELEASE_BRANCH="${BASH_REMATCH[1]}"
        FW_RELEASE_COMMIT="${BASH_REMATCH[2]}"
    fi
    if [ -z ${FW_RELEASE_BRANCH+x} ]; then
        echo "Empty value for FW_RELEASE_BRANCH, skipping"
        exit 0
    fi
    if [ -z ${FW_RELEASE_COMMIT+x} ]; then
        echo "Empty value for FW_RELEASE_COMMIT, skipping"
        exit 0
    fi
    if [ -z ${FW_RELEASE_VERSION+x} ]; then
        echo "Empty value for FW_RELEASE_VERSION, skipping"
        exit 0
    fi


    git clone git@gitlab.com:flywheel-io/infrastructure/release.git release_repo
    cd release_repo
    git checkout "$FW_RELEASE_BRANCH"

    replace() { sed -Ei "s|$2|$3|" $1; }
    replace .gitlab-ci.yml "RELEASECI_${FW_RELEASE_COMPONENT}_VERSION:.*" "RELEASECI_${FW_RELEASE_COMPONENT}_VERSION: ${FW_RELEASE_VERSION}"

    # for testing
    git diff

    git commit -am "$FW_RELEASE_COMMIT"
    #git push -f origin "$FW_RELEASE_BRANCH"

    cd ../ && rm -rf release_repo
}

main "$@"
