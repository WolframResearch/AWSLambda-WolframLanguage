#!/bin/bash

handler="${1:-app.pi}"

# --user=4242 is to simulate running as an arbitrary user

echo "Starting Lambda RIE with handler '$handler' on port 9000 - send invocations like:"
echo "> curl -XPOST 'http://localhost:9000/2015-03-31/functions/function/invocations' -d '{\"key\": \"value\"}'"
echo '---------'

docker run \
  -p 9000:8080 \
  -e WOLFRAMSCRIPT_ENTITLEMENTID=O-WSDS-B506-4HKBHTL77B4ZW \
  -e WOLFRAM_LAMBDA_HTTP_USE_BINARY_RESPONSE=0 \
  --read-only --tmpfs='/tmp' \
  --user=4242 \
  790731757232.dkr.ecr.us-east-1.amazonaws.com/aws-lambda-wolframlanguage-demo:latest \
  $handler