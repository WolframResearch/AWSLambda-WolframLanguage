# Contributing to Wolfram<sup>&reg;</sup>

Thank you for taking the time to contribute to the [Wolfram Research](https://github.com/wolframresearch) repos on GitHub.

## Licensing of Contributions

By contributing to Wolfram, you agree and affirm that:

> Wolfram may release your contribution under the terms of the [MIT license](https://opensource.org/licenses/MIT); and

> You have read and agreed to the [Developer Certificate of Origin](http://developercertificate.org/), version 1.1 or later.

Please see [LICENSE](LICENSE) for licensing conditions pertaining
to individual repositories.


## Bug reports

### Security Bugs

Please **DO NOT** file a public issue regarding a security issue.
Rather, send your report privately to security@wolfram.com.  Security
reports are appreciated and we will credit you for it.  We do not offer
a security bounty, but the forecast in your neighborhood will be cloudy
with a chance of Wolfram schwag!

### General Bugs

Please use the repository issues page to submit general bug issues.

Please do not duplicate issues.

Please do send a complete and well-written report to us.  Note:  **the
thoroughness of your report will positively correlate to our willingness
and ability to address it**.

When reporting issues, always include:

* Lambda function [console logs](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-logging.html) from a failed invocation, if relevant.
  * If possible, set the environment variable `WOLFRAM_LAMBDA_DEBUG_LOGS=1` on the Lambda function in order to include debugging information in the console logs.