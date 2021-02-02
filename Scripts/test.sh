#!/bin/bash

docker run \
  -p 9000:8080 \
  -e WOLFRAMSCRIPT_ENTITLEMENTID=O-WSDS-B506-4HKBHTL77B4ZW \
  790731757232.dkr.ecr.us-east-1.amazonaws.com/wolframresearch/aws-lambda-wolframlanguage:latest \
  app.func1