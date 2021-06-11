# Example AWS SAM app - HTTP mode function

This project contains source code and supporting files for an example Wolfram Language-based serverless application that you can deploy with the [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) CLI. It includes the following files and folders:

- [`example-http-function/`](example-http-function/): The application's Lambda function.
  - [`http-handler-file.wl`](example-http-function/http-handler-file.wl): Code for the function (a [`URLDispatcher`](https://reference.wolfram.com/language/ref/URLDispatcher.html) containing resources like [`APIFunction`](https://reference.wolfram.com/language/ref/APIFunction.html) and [`FormFunction`](https://reference.wolfram.com/language/ref/FormFunction.html))
  - [`Dockerfile`](example-http-function/Dockerfile): Build configuration for the function's associated container image.
- [`template.yaml`](template.yaml): A template that defines the application's AWS resources.

The application uses several AWS resources, including a Lambda function and an [API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html) API. These resources are defined in the [`template.yaml`](template.yaml) file in this project. You can update the template to add AWS resources through the same deployment process that updates your application code.

**NOTE:** The [default configuration](template.yaml) of this example enables [provisioned concurrency](https://docs.aws.amazon.com/lambda/latest/dg/configuration-concurrency.html#configuration-concurrency-provisioned) on the application's Lambda function in order to ensure quick response times from the deployed API. Provisioned concurrency has an [associated cost](https://aws.amazon.com/lambda/pricing/#Provisioned_Concurrency_Pricing). At the time of writing, for this example function as configured, the cost in the `us-east-1` region is ~$0.008 per hour (~$5.71/month), in addition to pricing based on request count and duration. If you don't want to use provisioned concurrency, you should remove the relevant lines in [`template.yaml`](template.yaml) before deploying the application.


## Install dependencies

To follow this walkthrough, you will need the following tools:
- AWS CLI - [Install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html); [Configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-config)
- AWS SAM CLI - [Install the AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
- Docker - [Install Docker Engine](https://docs.docker.com/engine/install/)

This walkthrough assumes that you have installed these tools, have access to [an AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/) and [security credentials](https://docs.aws.amazon.com/general/latest/gr/aws-security-credentials.html), and have access to the Wolfram Language through a product like [Wolfram Mathematica](https://www.wolfram.com/mathematica/) or [Wolfram Engine](https://www.wolfram.com/engine/).


## Create an Wolfram Engine on-demand license entitlement

In order for the [Wolfram Engine](https://www.wolfram.com/engine/) kernel inside the Lambda function's container to run, it must be [activated](https://reference.wolfram.com/language/tutorial/ActivatingMathematica.html) using **on-demand licensing**.

On-demand licensing is a pay-as-you-go licensing method whereby Wolfram Engine usage is billed against your [Wolfram Service Credits](https://www.wolfram.com/service-credits/) balance at a per-kernel-hour rate.
This method allows you to run arbitrary numbers of concurrent Wolfram Engine kernels for pennies per kernel per hour, and to scale up and down in a cost-effective manner.
You may use the starter Service Credits quota available with a free Wolfram Cloud Basic account for initial experimentation before purchasing more Service Credits.

An on-demand license entitlement is a reusable license key that can be used to activate one or more Wolfram Engine kernels.
Creating an entitlement requires access to the Wolfram Language.
If you do not have [Wolfram Mathematica](https://www.wolfram.com/mathematica/), a [Wolfram|One](https://www.wolfram.com/wolfram-one/) subscription or another Wolfram Language product, you can sign up for a free [Wolfram Cloud Basic](https://www.wolframcloud.com/) subscription and create an entitlement from within a cloud notebook.

Use the [`CreateLicenseEntitlement` function](https://reference.wolfram.com/language/ref/CreateLicenseEntitlement.html) to create a new license entitlement linked to your Wolfram Account:
```wl
In[1]:= entitlement = CreateLicenseEntitlement[<|
    "StandardKernelLimit" -> 10, 
    "LicenseExpiration" -> Quantity[1, "Week"], 
    "EntitlementExpiration" -> Quantity[1, "Years"]
|>]

Out[1]= LicenseEntitlementObject["O-WSTD-DA42-GKX4Z6NR2DSZR", <|
    "PolicyID" -> "WSTD", "PolicyName" -> "Standard", "BillingInterval" -> Quantity[900, "Seconds"],
    "KernelCosts" -> <|
        "Standard" -> Quantity[4., "Credits"/"Hours"],
        "Parallel" -> Quantity[4., "Credits"/"Hours"]
    |>,
    "KernelLimits" -> <|"Standard" -> 6, "Parallel" -> 0|>,
    "CreationDate" -> DateObject[{2021, 4, 28, 16, 50, 49.}, "Instant", "Gregorian", -4.], 
    "ExpirationDate" -> DateObject[{2022, 4, 28, 16, 50, 49.}, "Instant", "Gregorian", -4.],
    "LicenseExpirationDuration" -> Quantity[MixedMagnitude[{7, 0.}], 
    MixedUnit[{"Days", "Hours"}]]
|>]
```

Take note of the returned entitlement ID (`O-WSTD-DA42-GKX4Z6NR2DSZR` above); you will need it when you deploy your application in a subsequent step. This entitlement ID should be treated as an application secret and not committed to source control or exposed to the public.

The meanings of the specified entitlement settings are:
- `"StandardKernelLimit" -> 10`: Up to ten kernels may run concurrently. (This means ten instances of your Lambda function.)
- `"LicenseExpiration" -> Quantity[1, "Week"]`: Each kernel may run for up to one week at a time.
- `"EntitlementExpiration" -> Quantity[1, "Years"]`: The entitlement expires one year after creation. (This means you must create a new entitlement and replace it in your application once a year.)

You may adjust these settings as needed for your use case. For more information, see the documentation for [`CreateLicenseEntitlement`](https://reference.wolfram.com/language/ref/CreateLicenseEntitlement.html).


## Create an ECR repository

*The instructions in this section are based on the AWS blog post ["Using container image support for AWS Lambda with AWS SAM"](https://aws.amazon.com/blogs/compute/using-container-image-support-for-aws-lambda-with-aws-sam/).*

Before deploying your application, you must create an [Amazon Elastic Container Registry (ECR)](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html) repository in which to store the container image for your function.

To create the repository, run the following in your shell:
```bash
$ aws ecr create-repository --repository-name example-http-wl-sam-app
```

This will return a JSON document like:
```json
{
    "repository": {
        "repositoryArn": "arn:aws:ecr:us-east-1:123456789012:repository/example-http-wl-sam-app",
        "registryId": "123456789012",
        "repositoryName": "example-http-wl-sam-app",
        "repositoryUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/example-http-wl-sam-app", 
        "createdAt": "2021-04-28T17:27:48-04:00",
        "imageTagMutability": "MUTABLE",
        "imageScanningConfiguration": {
            "scanOnPush": false
        },
        "encryptionConfiguration": {
            "encryptionType": "AES256"
        }
    }
}
```

Take note of the `repositoryUri`; you will need it when you deploy your application in the next step.

Ensure that your local Docker daemon is [authenticated to your account's ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html#cli-authenticate-registry):

```bash
$ aws ecr get-login-password | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```
(Replace `123456789012.dkr.ecr.us-east-1.amazonaws.com` with the domain name component of the `repositoryUri` from the previous command result.)

You can also install the [Amazon ECR Docker Credential Helper](https://github.com/awslabs/amazon-ecr-credential-helper) to facilitate Docker authentication with Amazon ECR.


## Deploy the example application

The Serverless Application Model Command Line Interface (SAM CLI) is an extension of the AWS CLI that adds functionality for building and testing Lambda applications. It uses Docker to build a container image containing your function code, and it interfaces with [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) to deploy your application to AWS. For more information on using container image-based Lambda functions with AWS SAM, see the AWS blog post ["Using container image support for AWS Lambda with AWS SAM"](https://aws.amazon.com/blogs/compute/using-container-image-support-for-aws-lambda-with-aws-sam/).

To build and deploy your application for the first time, run the following in your shell:

```bash
$ sam build
$ sam deploy --guided
```

The first command will build a container image from the [Dockerfile](example-http-function/Dockerfile). The second command will package and deploy your application to AWS after a series of prompts:

- **Stack Name**: The name of the stack to deploy to CloudFormation. This should be unique to your account and region. In this example, we will use `example-http-wl-sam-app`.
- **AWS Region**: The [AWS region](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-regions) you want to deploy your app to.
- **Parameter OnDemandLicenseEntitlementID**: Your license entitlement ID from the previous step. This parameter is masked, so the text you type/paste will not be echoed back to you.
- **Image Repository for ExampleHTTPFunction**: The ECR `repositoryUri` from the previous step.
- **Confirm changes before deploy**: If enabled, any change sets will be shown to you for manual review before execution. If disabled, the AWS SAM CLI will automatically deploy application changes without prompting for review.
- **Allow SAM CLI IAM role creation**: Many AWS SAM templates, including this example, create AWS IAM roles required for the included AWS Lambda function(s) to access AWS services. By default, these are scoped down to minimum required permissions. To deploy an AWS CloudFormation stack that creates or modifies IAM roles, the `CAPABILITY_IAM` value for `capabilities` must be provided. If permission isn't provided through this prompt, to deploy this example you must explicitly pass `--capabilities CAPABILITY_IAM` to the `sam deploy` command.
- **ExampleHTTPFunction may not have authorization defined, Is this okay?**: This is [a security message](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-deploying.html#serverless-deploying-troubleshooting) warning you that the API Gateway API route linked to your Lambda function is configured to be publicly accessible. You can safely bypass this warning for the purposes of this walkthrough by typing `y`. In production scenarios or situations involving sensitive data you should evaluate the security requirements of your application.
- **Save arguments to configuration file**: If enabled, your choices will be saved to a `samlconfig.toml` configuration file in the current directory, so that in the future you can just re-run `sam deploy` without parameters to deploy changes to your application.
- **SAM configuration file** and **SAM configuration environment**: If you enabled the previous option, these options allow you to configure how the configuration file is saved. You may leave these options at their default values.

For more information, see [the documentation for `sam deploy`](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-cli-command-reference-sam-deploy.html).

The initial deployment of your application may take several minutes, as Docker will have to push the entire container image - including the Wolfram Engine base layers - to your ECR repository. Subsequent deployments will be faster, as only the changed portions of the image will be pushed.

You can find the URL of your API Gateway endpoint in the output values displayed after deployment:
```
Key                 ExampleHTTPFunctionAPI
Description         API Gateway endpoint URL for Prod stage for example HTTP-based function
Value               https://sqn96odt1j.execute-api.us-east-1.amazonaws.com/Prod/
```

If you visit this URL, you should see the root route of the [`URLDispatcher`](https://reference.wolfram.com/language/ref/URLDispatcher.html) from [the function's source file](example-http-function/http-handler-file.wl):

![HTML page served by the URLDispatcher in http-handler-file.wl](../../.images/HTTP-Function-URLDispatcher.png)


## Add a resource to your application

The [application template](template.yaml) uses the AWS Serverless Application Model (AWS SAM) to define application resources. AWS SAM is an extension of AWS CloudFormation with a simpler syntax for configuring common serverless application resources such as functions, triggers, and APIs. For resources not included in [the SAM specification](https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md), you can use standard [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-template-resource-type-ref.html) resource types.


## Fetch, tail, and filter Lambda function logs

To simplify troubleshooting, the SAM CLI has a command called `sam logs`. `sam logs` lets you fetch logs generated by your deployed Lambda function from the command line.

**NOTE:** This command works for all AWS Lambda functions; not just the ones you deploy using SAM.

```bash
$ sam logs -n ExampleHTTPFunction --stack-name example-http-wl-sam-app
```
```
2021/04/28/[1]394e19114a6149f097066a19c6a5da39 2021-04-28T23:02:03.084000 START RequestId: c3bf978f-59da-4bb3-9eb7-9a105fa93692 Version: 1
2021/04/28/[1]394e19114a6149f097066a19c6a5da39 2021-04-28T23:02:03.093000 >> Received request for root route
2021/04/28/[1]394e19114a6149f097066a19c6a5da39 2021-04-28T23:02:03.361000 END RequestId: c3bf978f-59da-4bb3-9eb7-9a105fa93692
2021/04/28/[1]394e19114a6149f097066a19c6a5da39 2021-04-28T23:02:03.361000 REPORT RequestId: c3bf978f-59da-4bb3-9eb7-9a105fa93692                                                                                                 Duration: 274.85 ms      Billed Duration: 275 ms Memory Size: 512 MB     Max Memory Used: 317 MB
```

You can add the `--tail` option to stream logs to your terminal in near-real time. You can find information and examples about filtering Lambda function logs in the [SAM CLI documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-logging.html).


## Cleanup

To delete the sample application that you created, use the AWS CLI to delete the application's CloudFormation stack:

```bash
$ aws cloudformation delete-stack --stack-name example-http-wl-sam-app
```


## Resources

See the [AWS SAM developer guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) for an introduction to SAM specification, the SAM CLI, and serverless application concepts.


<hr/>

*This file is derived from an AWS-provided SAM CLI application template. The original document from which this walkthrough has been modified is located [here](https://github.com/aws/aws-sam-cli-app-templates/blob/de97a7aac7ee8416f3310d7bd005b391f1ff1ac0/nodejs14.x-image/cookiecutter-aws-sam-hello-nodejs-lambda-image/%7B%7Bcookiecutter.project_name%7D%7D/README.md).*  
*The repository containing the original document is licensed under the [Apache-2.0 License](https://github.com/aws/aws-sam-cli-app-templates/blob/master/LICENSE), and carries the following notice:*  
*`Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.`*