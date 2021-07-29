# Wolfram Language runtime for AWS Lambda

## Quick Reference

- **Maintained by**: [Wolfram Research](https://www.wolfram.com/)
- **Where to get help**: [Wolfram Community](https://community.wolfram.com/), [GitHub issue tracker](https://github.com/WolframResearch/AWSLambda-WolframLanguage/issues)
- **Source code**: [GitHub repository](https://github.com/WolframResearch/AWSLambda-WolframLanguage)
- **License**:
  - The contents of the [Wolfram Language Runtime source code repository](https://github.com/WolframResearch/AWSLambda-WolframLanguage) are available under the [MIT License](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/LICENSE).
  - The Wolfram Engine product contained within the runtime container image is proprietary software, subject to the [terms of use](http://www.wolfram.com/legal/terms/wolfram-engine.html) listed on the Wolfram Research website.
  - To use the Wolfram Engine, you will need to sign up for a [(free) developer license](https://www.wolfram.com/developer-license). The developer license requires the creation of a Wolfram ID and acceptance of the terms of use.


## Supported Image Tags

- `latest` [_(Dockerfile)_](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Dockerfile)


## Image Variants

### `wolframresearch/aws-lambda-wolframlanguage:latest`

*Base: [`wolframresearch/wolframengine:latest`](https://hub.docker.com/r/wolframresearch/wolframengine)*  
This image is based on the `latest` tag of the `wolframresearch/wolframengine` image, and hence contains the latest version of the Wolfram Engine.


# Introduction

The Wolfram Language runtime for [AWS Lambda](https://aws.amazon.com/lambda/) is a [Lambda container image runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-images.html) that allows you to write [Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-concepts.html#gettingstarted-concepts-function) using the [Wolfram Language](https://www.wolfram.com/language/).

The WL Lambda runtime supports two main modes of operation:

## Raw mode

Raw-mode functions behave like conventional Lambda functions written in languages such as [JavaScript](https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html) and [Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html). Raw-mode functions are written as ordinary Wolfram Language functions. Raw-mode functions accept JSON data as input and return JSON or binary data as output.

For a walkthrough of deploying an raw-mode function, see the [raw mode example](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Examples/aws-sam/raw-mode/README.md). The template and code in this example can be adapted for your own applications.

## HTTP mode

HTTP-mode functions are intended to integrate with an [Amazon API Gateway](https://aws.amazon.com/api-gateway/) API and [proxy integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-create-api-as-simple-proxy). Much like applications using the [Wolfram Web Engine for Python](https://github.com/WolframResearch/WolframWebEngineForPython), HTTP-mode functions are written using high-level HTTP-aware primitives such as [`APIFunction`](https://reference.wolfram.com/language/ref/APIFunction.html) and [`FormFunction`](https://reference.wolfram.com/language/ref/FormFunction.html). Any primitive supported by the Wolfram Lnaguage function [`GenerateHTTPResponse`](https://reference.wolfram.com/language/ref/GenerateHTTPResponse.html) can be used in an HTTP-mode function. HTTP-mode functions accept HTTP request data as input and return HTTP response data as output.

For a walkthrough of deploying an HTTP-mode function, see the [HTTP mode example](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Examples/aws-sam/http-mode/README.md). The template and code in this example can be adapted for your own applications.