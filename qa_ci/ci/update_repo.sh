#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0

Update poetry.lock, Dockerfile, .gitlab-ci.yml and .pre-commit-config.yaml
"

# shellcheck disable=SC1091
. /ci/utils.sh

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test ! -f pyproject.toml || poetry update --lock
    /ci/update_docker.sh
    /ci/update_refs.sh
}

main "$@"
