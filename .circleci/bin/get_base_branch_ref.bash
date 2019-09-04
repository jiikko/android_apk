#!/usr/bin/env bash

set -eu
set -o pipefail

readonly username="${CIRCLE_PROJECT_USERNAME:-deploygate}"
readonly reponame="${CIRCLE_PROJECT_REPONAME:-android_apk}"
readonly pr_number="$(basename $CIRCLE_PULL_REQUEST)"

readonly api_url="https://api.github.com/repos/$username/$reponame/pulls/$pr_number"
curl -sSL -H 'Accept: application/vnd.github.v3+json' "$api_url" | jq -r '.base.ref'