#!/usr/bin/env bash
set -euo pipefail

# The productAPI service requires a database connection, which means it requires
# database credentials. Rather than hard-coding them in the job file, we can
# generate a random password, and store it plus a username as Nomad Variables.
# Reference: https://developer.hashicorp.com/nomad/docs/concepts/variables

readonly username='pgOnNomad1'

# Time-based passwords aren't cryptographically secure, so don't use this for
# anything actually sensitive.
if command -v md5 &> /dev/null; then
  readonly password=$(date | md5)
fi
if command -v md5sum &> /dev/null; then
  readonly password=$(date | md5sum | cut -f1 -d' ')
fi

jq -c --null-input --arg username "$username" --arg password "$password" \
'{
  "Items": {
    "username": $username,
    "password": $password
  }
}'

# Use this script's output as input to `nomad var put` in order to create the
# variable. For example:
# ./create_nomad_variable_input.sh | nomad var put -in json nomad/jobs/hashicups-productAPI -
