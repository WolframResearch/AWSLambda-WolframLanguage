FROM wolframresearch/aws-lambda-wolframlanguage:latest

COPY *.wl /var/task/

# Selected handler can be overridden by providing a different command in the template directly.
CMD ["http-handler-file"]
