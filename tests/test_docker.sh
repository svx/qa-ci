#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -eu
USAGE="Usage:
  $0 [IMAGE]...

Run basic smoke tests in a docker container to verify image functionality.
"


main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    if [ "${RUN_CONTAINER:-true}" = true ]; then
        IMAGE=${1:-flywheel/qa-ci}
        run_container "$IMAGE"
    else
        run_tests
    fi
}


run_container() {
    IMAGE=$1
    log "$0:run_container($IMAGE)"
    docker run --rm \
        -e "TRACE=${TRACE:-}" \
        -e "GITLAB_CI_BOT_READ_TOKEN=${GITLAB_CI_BOT_READ_TOKEN:-}" \
        -e "RUN_CONTAINER=false" \
        -v "$(pwd):/src" \
        -w /src \
        "$IMAGE" tests/test_docker.sh
}


run_tests() {
    log "$0:run_tests()"
    EXPECTED_BIN=(
        black
        docker
        docker-compose
        hadolint
        helm
        helm-docs
        jsonlint
        kubeval
        markdownlint
        pre-commit
        pydocstyle
        safety
        yamllint
    )
    for BIN in "${EXPECTED_BIN[@]}"; do
        quiet command -v "$BIN" || die "Command not found: $BIN"
    done
    for SCRIPT in /lint/link_check.py /lint/run.sh /helm/run.sh /ci/*.sh; do
        test -x "$SCRIPT" || die "Script is not executable: $SCRIPT"
    done
    test "$(id -u):$(id -g)" = 0:0 || die "Not running as root"
    test -n "${KUBERNETES:-}" || die "KUBERNETES envvar not set"
    quiet ls /etc/kubeval/*/ || die "K8S schema not found"
    test_latest_img
    test_update_refs
}


test_latest_img() {
    # shellcheck disable=SC1091
    . /ci/utils.sh

    DATE="[0-9]{8}"
    VER="[0-9]+(\.[0-9]+){1,2}"
    HASH="[0-9a-f]{8}"
    TESTS=(
        "ubuntu                 ubuntu:focal-$DATE"
        "ubuntu:latest          ubuntu:focal-$DATE"
        "ubuntu:18.04           ubuntu:bionic-$DATE"
        "ubuntu:bionic-20210325 ubuntu:bionic-$DATE"

        "python        python:$VER-buster"
        "python:latest python:$VER-buster"
        "python:3      python:$VER-buster"
        "python:3.8    python:$VER-buster"
        "python:3.8.8  python:$VER-buster"

        "python:alpine           python:$VER-alpine$VER"
        "python:3-alpine         python:$VER-alpine$VER"
        "python:3.8-alpine       python:$VER-alpine$VER"
        "python:3.8.8-alpine     python:$VER-alpine$VER"
        "python:3.8.8-alpine3.13 python:$VER-alpine$VER"

        "flywheel/python                 flywheel/python:master\.$HASH"
        "flywheel/python:latest          flywheel/python:master\.$HASH"
        "flywheel/python:master          flywheel/python:master\.$HASH"
        "flywheel/python:master.cc52122b flywheel/python:master\.$HASH"
    )
    for TEST in "${TESTS[@]}"; do
        IMAGE=$(echo "$TEST" | tr -s " " | cut -d" " -f1)
        REGEX=$(echo "$TEST" | tr -s " " | cut -d" " -f2)
        LATEST=$(_latest_img_version "$IMAGE")
        if echo "$LATEST" | grep -Eq "$REGEX"; then
            log "test_latest_img[$IMAGE -> $LATEST] pass"
        else
            die "test_latest_img[$IMAGE -> $LATEST] fail - expected $REGEX"
        fi
    done
}


test_update_refs() {
    if [ -z "${GITLAB_CI_BOT_READ_TOKEN:-}" ]; then
        log "test_update_refs skip (GITLAB_CI_BOT_READ_TOKEN not set)"
        return
    fi
    DIR=$(mktemp -d)
    cp -r /src/tests/data "$DIR"
    cd "$DIR/data"

    unset PIN_CI_REFS
    /ci/update_refs.sh

    grep -n "#" .gitlab-ci.yml .pre-commit-config.yaml | while read -r LINE; do
        YAML="${LINE/  \# */}"
        REGEX="${LINE/*# /}"
        if echo "$YAML" | grep -Eq "$REGEX"; then
            log "test_update_refs[$YAML] pass"
        else
            die "test_update_refs[$YAML] fail - expected $REGEX"
        fi
    done
}


# logging and formatting utilities
log() { printf "\e[32mINFO\e[0m %s\n" "$*" >&2; }
err() { printf "\e[31mERRO\e[0m %s\n" "$*" >&2; }
die() { err "$@"; exit 1; }
quiet() { "$@" >/dev/null 2>&1; }


main "$@"
