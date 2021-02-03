#!/bin/bash

handler="${1:-app.pi}"

# --user=4242 is to simulate running as an arbitrary user

docker run \
  -p 9000:8080 \
  -e WOLFRAMSCRIPT_ENTITLEMENTID=O-WSDS-B506-4HKBHTL77B4ZW \
  --read-only --tmpfs="/tmp" \
  --user=4242 \
  790731757232.dkr.ecr.us-east-1.amazonaws.com/aws-lambda-wolframlanguage-demo:latest \
  $handler