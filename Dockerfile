FROM wolframresearch/wolframengine:latest

USER root

# temporary workaround for bug(413167)
RUN apt-get update -y && \
  apt-get install -y libglib2.0-0

ENV LAMBDA_TASK_ROOT=/var/task
ENV LAMBDA_RUNTIME_DIR=/var/runtime

# add the Lambda RIE for debugging
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/local/bin/aws-lambda-rie

COPY AWSLambdaRuntime /usr/share/WolframEngine/Applications/AWSLambdaRuntime

COPY runtime-entrypoint.sh /runtime-entrypoint.sh
COPY runtime-kernel-wrapper.sh /runtime-kernel-wrapper.sh

# patch layout with libiomp5.so from WL 12.3.1, to work around OpenMP/MKL
# incompatibility issue in 13.0.0 relating to /dev/shm not working in Lambda
COPY --from=wolframresearch/wolframengine:12.3.1 \
  /usr/local/Wolfram/WolframEngine/12.3/SystemFiles/Libraries/Linux-x86-64/libiomp5.so \
  /usr/local/Wolfram/WolframEngine/13.0/SystemFiles/Libraries/Linux-x86-64/libiomp5.so

RUN chmod a+rx \
  /usr/local/bin/aws-lambda-rie \
  /runtime-entrypoint.sh \
  /runtime-kernel-wrapper.sh

USER wolframengine

WORKDIR $LAMBDA_TASK_ROOT

ENTRYPOINT ["/runtime-entrypoint.sh"]