#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 [Dockerfile]...

Update dependency version pins in one or more Dockerfiles:
- Update base image:tag                    (to disable: PIN_IMG=true)
- Update system packages - apk or apt      (to disable: PIN_PKG=pk1[,pkg2])
- Update python packages installed via pip (to disable: PIN_PIP=pk1[,pkg2])
- Update node packages installed via npm   (to disable: PIN_NPM=pk1[,pkg2])

Checks all files matching glob Dockerfile* if no args are specified. Custom
updates are sourced from 'update_docker.sh' at the repo root if the file
exists - the custom update script is typically used for getting the latest
release version of a github project and replacing a Dockerfile ARG or ENV.
For example:
> replace JQ_VERSION=.* \$(latest_version git stedolan/jq)
"

# shellcheck disable=SC1091
. /ci/utils.sh


main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test $# -gt 0 || set -- Dockerfile*
    test -f "$1" || { log "No Dockerfile to update - exiting $0"; exit; }
    for DOCKERFILE in "$@"; do
        log "Updating $DOCKERFILE"
        test -f "$DOCKERFILE" || die "$DOCKERFILE not found"
        HASH=$(md5sum "$DOCKERFILE")
        update "$DOCKERFILE"
        if [ "$(md5sum "$DOCKERFILE")" = "$HASH" ]; then
            log "$DOCKERFILE already up to date"
        else
            log "$DOCKERFILE updated"
        fi
    done
}


update() {
    DOCKERFILE=$1
    IMG=$(get_base_img)
    if [ "${PIN_IMG:-}" != true ]; then
        NEW=$(latest_version img "$IMG")
        replace "$IMG" "$NEW"
        IMG=$NEW
    fi
    quiet docker rm -f pkg || true
    quiet docker run -dt --rm --name pkg --entrypoint=/bin/sh "$IMG" -c "sleep 300"
    trap "quiet docker rm -f pkg" INT TERM EXIT
    quiet drun command -v apk && PKG_MGR=apk || PKG_MGR=apt
    test "$PKG_MGR" != apt || drun apt-get update -qqy
    for PKG in $(get_packages "$PKG_MGR"); do
        PKG_NAME=${PKG/=*/}
        echo "${PIN_PKG:-}" | grep -qvw "$PKG_NAME" || continue
        replace "$PKG" "$PKG_NAME=$(latest_version "$PKG_MGR" "$PKG_NAME")"
    done
    for PKG in $(get_packages pip); do
        PKG_NAME=${PKG/=*/}
        echo "${PIN_PIP:-}" | grep -qvw "$PKG_NAME" || continue
        replace "$PKG" "$PKG_NAME==$(latest_version pip "$PKG_NAME")"
    done
    for PKG in $(get_packages npm); do
        PKG_NAME=${PKG/@*/}
        echo "${PIN_NPM:-}" | grep -qvw "$PKG_NAME" || continue
        replace "$PKG" "$PKG_NAME@$(latest_version npm "$PKG_NAME")"
    done
    if test -f update_docker.sh; then
        # shellcheck disable=SC1091
        . update_docker.sh
    fi
}


# helpers for getting information from the dockerfile
get_base_img() {
    grep -Eo "^FROM .*" "$DOCKERFILE" \
        | sed -E "s/FROM ([^[:space:]]+).*/\1/" | head -n1
}

get_packages() { log "get_${1}_packages..."; "_get_${1}_packages"; }
_get_apk_packages() { _get_cmd_args "apk add"; }
_get_apt_packages() { _get_cmd_args "apt-get install"; }
_get_pip_packages() { _get_cmd_args "pip install"; }
_get_npm_packages() { _get_cmd_args "npm install"; }
_get_cmd_args() {
    # read the dockerfile line by line (escaped newlines don't count)
    # shellcheck disable=SC2162
    while IFS="" read LINE; do
        # skip the line if it's not a RUN instruction
        echo "$LINE" | grep -Eq "^RUN " || continue
        # read the RUN line command by command (ie. split on ";")
        while IFS="" read -r CMD; do
            # strip the whitespace from the beginning
            CMD=$(echo "$CMD" | strip)
            # skip if the command doesn't start as expected (param $1)
            echo "$CMD" | grep -Eq "^$1" || continue
            # echo each package argument of the command
            for ARG in ${CMD:${#1}}; do
                ARG=$(echo "$ARG" | strip)
                # skip arguments that aren't package names
                echo "$ARG" | grep -Eqv '^-' || continue  # option (--no-install-recommends)
                echo "$ARG" | grep -Eqv '\$' || continue  # variable ($VERSION)
                echo "$ARG" | grep -Eqv '^\.' || continue  # virtual apk package (.build-deps)
                echo "$ARG" | grep -Eqv '\.txt$' || continue  # pip requirements.txt
                echo "$ARG"
            done
        done < <(echo "${LINE:4}" | tr ";" "\n" | sed "s/&&/\n/")
    done <"$DOCKERFILE"
}

# dockerized helpers for getting latest system package versions
drun() { docker exec -t pkg /bin/sh -c "$*" | strip; }
_latest_apk_version() {
    drun apk --no-cache search --exact "$1" | grep -v fetch | grep -Eo "[0-9].*"
}
_latest_apt_version() {
    drun apt-cache policy "$1" | grep Candidate | grep -Eo "[0-9].*"
}

# shorthand for pattern-replacing in the dockerfile via sed
replace() { sed -Ei "s|$1|$2|" "$DOCKERFILE"; }


main "$@"
