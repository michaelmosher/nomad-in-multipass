#!/usr/bin/env bash
set -euo pipefail

readonly nomadIP=$(multipass info --format json nomad-test-1 \
    | jq -r '.info["nomad-test-1"].ipv4[0]')

export NOMAD_ADDR="http://$nomadIP:4646"
nomad $@
