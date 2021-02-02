#!/bin/bash

docker build . \
  -t wolframresearch/aws-lambda-wolframlanguage:latest

docker build Demo \
  -t 790731757232.dkr.ecr.us-east-1.amazonaws.com/aws-lambda-wolframlanguage-demo:latest