#!/bin/sh

WL_SHIM_CODE='Needs["AWSLambdaRuntime`"]; AWSLambdaRuntime`StartRuntime[]'

_HANDLER="${_HANDLER:-${1:-app}}"
export _HANDLER

if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
  exec /usr/local/bin/aws-lambda-rie /usr/bin/wolframscript -code "$WL_SHIM_CODE"
else
  exec /usr/bin/wolframscript -code "$WL_SHIM_CODE"
fi