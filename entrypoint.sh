#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
exec tini -- gosu nobody "$@"
