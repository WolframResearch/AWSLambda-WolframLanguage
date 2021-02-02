FROM wolframresearch/wolframengine:latest

USER root

COPY AWSLambdaRuntime /home/wolframengine/.WolframEngine/Applications/AWSLambdaRuntime
COPY entry_script.sh /entry_script.sh

ENV LAMBDA_TASK_ROOT=/var/task
WORKDIR $LAMBDA_TASK_ROOT

# add the Lambda RIE for debugging use
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/local/bin/aws-lambda-rie
RUN chmod +x /usr/local/bin/aws-lambda-rie

USER wolframengine

ENTRYPOINT ["/entry_script.sh"]