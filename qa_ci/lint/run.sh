#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0

test:flywheel-lint entrypoint running dockerized pre-commit hooks defined in
/qa_ci/lint/hooks.yml
"

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }

    # shellcheck disable=SC1091
    [ ! -f .env ] || { set -a; . .env; set +a; }

    # create a backup of the pre-commit config (if it exists)
    # and replace with the lint config shipped with the image
    export CONFIG=.pre-commit-config.yaml
    [ ! -f "$CONFIG" ] || mv "$CONFIG" "$CONFIG.bak"
    cp /lint/hooks.yml "$CONFIG"

    # add default linter configs if custom ones aren't present
    [ -f .markdownlint.json ] || cp /lint/.markdownlint.json ./
    [ -f .yamllint.yml ] || cp /lint/.yamllint.yml ./

    # run pre-commit hooks
    export PRE_COMMIT_HOME=/tmp/pre-commit-cache
    pre-commit run --all-files --color always || EXIT_CODE=$?

    # reset any injected default linter configs
    git checkout .markdownlint.json 2>/dev/null || rm .markdownlint.json
    git checkout .yamllint.yml 2>/dev/null || rm .yamllint.yml

    # restore the original pre-commit config and exit
    [ ! -f "$CONFIG.bak" ] || mv "$CONFIG.bak" "$CONFIG"
    exit "${EXIT_CODE:-0}"
}

main "$@"
