# Wolfram Language runtime for AWS Lambda

## Introduction

The Wolfram Language runtime for [AWS Lambda](https://aws.amazon.com/lambda/) is a [Lambda container image runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-images.html) that allows you to write [Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-concepts.html#gettingstarted-concepts-function) using the [Wolfram Language](https://www.wolfram.com/language/).

You can use the WL Lambda runtime to deploy your Wolfram Language code scalably in AWS' global infrastructure and integrate it with other applications and clients both within and outside of the AWS cloud.

You can also integrate the WL Lambda runtime with [Amazon API Gateway](https://aws.amazon.com/api-gateway/) to host Wolfram Language-based web applications, such as [APIs](https://reference.wolfram.com/language/guide/CreatingAnInstantAPI.html) and [web forms](https://reference.wolfram.com/language/guide/CreatingFormsAndApps.html), on AWS Lambda.

## Quick reference

- **Maintained by**: [Wolfram Research](https://www.wolfram.com/)
- **Where to get help**: [Wolfram Community](https://community.wolfram.com/), [GitHub issue tracker](https://github.com/WolframResearch/AWSLambda-WolframLanguage/issues)
- **Source code**: [GitHub repository](https://github.com/WolframResearch/AWSLambda-WolframLanguage)
- **Container image**: [Docker Hub repository](https://hub.docker.com/r/wolframresearch/aws-lambda-wolframlanguage)
- **License**:
  - The contents of the [Wolfram Language Lambda Runtime source code repository](https://github.com/WolframResearch/AWSLambda-WolframLanguage) are available under the [MIT License](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/LICENSE).
  - The Wolfram Engine product contained within the runtime container image is proprietary software, subject to the [terms of use](http://www.wolfram.com/legal/terms/wolfram-engine.html) listed on the Wolfram Research website.
  - To use the Wolfram Engine, you will need to sign up for a [(free) developer license](https://www.wolfram.com/developer-license). The developer license requires the creation of a Wolfram ID and acceptance of the terms of use.


## Function modes

The WL Lambda runtime supports two main modes of operation:

### Raw mode _([walkthrough »](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Examples/aws-sam/raw-mode/README.md))_

Raw-mode functions behave like conventional Lambda functions written in languages such as [JavaScript](https://docs.aws.amazon.com/lambda/latest/dg/nodejs-handler.html) and [Python](https://docs.aws.amazon.com/lambda/latest/dg/python-handler.html). Raw-mode functions are written as ordinary Wolfram Language functions. Raw-mode functions accept JSON data as input and return JSON or binary data as output.

A raw-mode Lambda function can be written as a pure function accepting an association of deserialized JSON data, like:
```wl
Function[<|
    "reversed" -> StringReverse[#inputString]
|>]
```
This function would accept input JSON like:
```json
{"inputString": "Hello World"}
```
...and return as output (automatically serialized to JSON):
```json
{"reversed": "dlroW olleH"}
```

Raw-mode functions can be [invoked](https://docs.aws.amazon.com/lambda/latest/dg/lambda-invocation.html) using the [AWS Lambda API](https://docs.aws.amazon.com/lambda/latest/dg/API_Invoke.html); [AWS SDKs](https://aws.amazon.com/tools/), the [AWS CLI](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/lambda/invoke.html) and other AWS tools; and [other AWS services](https://docs.aws.amazon.com/lambda/latest/dg/lambda-services.html) such as [Lex](https://docs.aws.amazon.com/lambda/latest/dg/services-lex.html), [S3](https://docs.aws.amazon.com/lambda/latest/dg/with-s3.html) and [SNS](https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html). Wolfram Language clients can invoke arbitrary Lambda functions using the [AWS service connection](https://reference.wolfram.com/language/ref/service/AWS.html).

For a complete walkthrough of deploying an raw-mode function, see the [raw mode example](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Examples/aws-sam/raw-mode/README.md). The template and code in this example can be adapted for your own applications.

### HTTP mode _([walkthrough »](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Examples/aws-sam/http-mode/README.md))_

HTTP-mode functions are intended to integrate with an [Amazon API Gateway](https://aws.amazon.com/api-gateway/) API and [proxy integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-create-api-as-simple-proxy). Much like applications using the [Wolfram Web Engine for Python](https://github.com/WolframResearch/WolframWebEngineForPython), HTTP-mode functions are written using high-level HTTP-aware primitives such as [`APIFunction`](https://reference.wolfram.com/language/ref/APIFunction.html) and [`FormFunction`](https://reference.wolfram.com/language/ref/FormFunction.html). Any primitive supported by the Wolfram Language function [`GenerateHTTPResponse`](https://reference.wolfram.com/language/ref/GenerateHTTPResponse.html) can be used in an HTTP-mode function. HTTP-mode functions accept HTTP request data as input and return HTTP response data as output.

An HTTP-mode Lambda function can be written using Wolfram Language HTTP-aware primitives, such as [`FormPage`](https://reference.wolfram.com/language/ref/FormPage.html):
```
FormPage[
    {"image" -> "Image"},
    ImageEffect[#image, "Charcoal"] &
]
```
When deployed to AWS Lambda and Amazon API Gateway, the form page is accessible in a web browser via an API Gateway URL:

![HTML page served by a FormPage in an HTTP-mode Lambda function](https://raw.githubusercontent.com/WolframResearch/AWSLambda-WolframLanguage/master/Examples/.images/HTTP-Function-FormPage.png)

HTTP-mode functions can be invoked via API Gateway by a web browser or any HTTP-capable program, including by Wolfram Language-based clients.

For a complete walkthrough of deploying an HTTP-mode function, see the [HTTP mode example](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Examples/aws-sam/http-mode/README.md). The template and code in this example can be adapted for your own applications.


## Container image information

### Supported image tags

- `latest` [_(Dockerfile)_](https://github.com/WolframResearch/AWSLambda-WolframLanguage/blob/master/Dockerfile)


### Image variants

#### `wolframresearch/aws-lambda-wolframlanguage:latest`

*Base: [`wolframresearch/wolframengine:latest`](https://hub.docker.com/r/wolframresearch/wolframengine)*  
This image is based on the `latest` tag of the `wolframresearch/wolframengine` image, and hence contains the latest version of the [Wolfram Engine](https://www.wolfram.com/engine/).