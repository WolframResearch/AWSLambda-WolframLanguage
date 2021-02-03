#!/bin/sh

# use, in order: existing _HANDLER; first argument; string "app"
export _HANDLER="${_HANDLER:-${1:-app}}"

if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
  exec /usr/local/bin/aws-lambda-rie /runtime-kernel-wrapper.sh $_HANDLER
else
  exec /runtime-kernel-wrapper.sh
fi