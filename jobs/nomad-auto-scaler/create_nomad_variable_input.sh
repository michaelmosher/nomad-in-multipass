#!/usr/bin/env bash
set -Eeuo pipefail

readonly multipassDataPath='/var/root/Library/Application Support/multipassd'

readonly localMultipassCert="$multipassDataPath/certificates/localhost.pem"
readonly localMultipassKey="$multipassDataPath/certificates/localhost_key.pem"

# The multipass-target plugin for the Nomad autoscaler service requires a TLS
# key and certificate. For that, we can reuse the key-pair the multipass CLI
# uses. This script will read those files and parse them into JSON, which can be
# used by `nomad var put` in order to store the value as a Nomad Variable.
# Reference: https://developer.hashicorp.com/nomad/docs/concepts/variables

jq -c --null-input \
    --arg cert "$(cat "$localMultipassCert")" \
    --arg key "$(cat "$localMultipassKey")" \
'{
    "Items": {
        "client_cert": $cert,
        "client_key": $key,
    }
}'

# Use this script's output as input to `nomad var put` in order to create the
# variable. For example:
# ./create_nomad_variable_input.sh | nomad var put -in json nomad/jobs/nomad-auto-scaler -

# ipconfig getifaddr en0
