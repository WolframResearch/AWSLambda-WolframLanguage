BeginPackage["AWSLambdaRuntime`"]

AWSLambdaRuntime`StartRuntime

Begin["`Private`"]

(* ::Section:: *)
(* Environment variables *)

$LambdaRuntimeAPIHost = Environment["AWS_LAMBDA_RUNTIME_API"]
$LambdaRuntimeAPIVersion = "2018-06-01"

(* ::Section:: *)
(* Handler initialization and main loop *)

AWSLambdaRuntime`StartRuntime[] := Module[{
    handler,
    invocationData
},
    If[
        (* if the API host is not set *)
        !StringQ[$LambdaRuntimeAPIHost],
        (* then print an error and quit (we can't emit a proper initialization error
            to the API if we don't know what the API host is...) *)
        Print["FATAL RUNTIME ERROR: AWS_LAMBDA_RUNTIME_API environment variable not set"];
        Exit[40];
    ];
    Echo["starting runtime!"];
    Echo[GetEnvironment[], "environment"];

    (* load the handler function from the handler file *)
    handler = loadHandler[];

    Which[
        (* if loadHandler failed *)
        FailureQ[handler],
        (* then emit an error and exit *)
        exitWithInitializationError[handler],

        (* if the extracted handler is not an APIFunction (sanity check) *)
        Head[handler] =!= APIFunction,
        (* then emit an error and exit *)
        exitWithInitializationError@Failure["InvalidHandler", <|
            "MessageTemplate" -> StringJoin[{
                "The handler expression with head `1` is not an APIFunction expression"
            }],
            "MessageParameters" -> {Head[handler]}
        |>]
    ];

    (* main loop: long-poll for invocations and process them *)
    While[True,
        invocationData = getNextInvocation[];
        processInvocation[invocationData, handler];
    ];

    Exit[0]
]

(* ::Subsection:: *)
(* Load user handler *)

loadHandler[] := Module[{
    taskRootDirectory = Lookup[
        GetEnvironment[],
        "LAMBDA_TASK_ROOT",
        "/var/task"
    ],
    handlerSpec = Lookup[
        GetEnvironment[],
        "_HANDLER",
        "app"
    ],
    allowedHandlerFileExtensions = "wl" | "m" | "mx",

    handlerFileBaseName,
    handlerName,
    matchingHandlerFilenames,
    handlerFileName,

    handlerFileReturnValue
},
    If[
        (* if we can't change to the task root directory (i.e. it doesn't exist) *)
        FailureQ[SetDirectory[taskRootDirectory]],
        (* then return a Failure *)
        Return@Failure["SetDirectoryFailure", <|
            "MessageTemplate" -> "Failed to set current directory to `1`",
            "MessageParameters" -> {taskRootDirectory}
        |>]
    ];

    {handlerFileBaseName, handlerName} = PadRight[StringSplit[handlerSpec, ".", 2], 2, None];
    matchingHandlerFilenames = FileNames[StringExpression[
        handlerFileBaseName,
        ".",
        allowedHandlerFileExtensions
    ]];

    If[
        (* if there's no file matching the expected handler name pattern *)
        Length[matchingHandlerFilenames] === 0,
        (* then return a Failure *)
        Return@Failure["HandlerFileNotFound", <|
            "MessageTemplate" -> "Could not find a handler file with name `name`.[`exts`] in directory `directory`",
            "MessageParameters" -> <|
                "name" -> handlerFileBaseName,
                "exts" -> StringRiffle[List @@ allowedHandlerFileExtensions, ","],
                "directory" -> taskRootDirectory
            |>
        |>]
    ];

    handlerFileName = ExpandFileName@First[matchingHandlerFilenames];

    handlerFileReturnValue = withCleanContext@Get[handlerFileName];

    handler = sanitizeHandler[handlerFileReturnValue];

    If[
        (* if the value returned by the handler file is invalid *)
        FailureQ[handler],
        (* then return the corresponding Failure *)
        Return[handler]
    ];

    If[
        (* if the handler file returned a set of multiple functions *)
        AssociationQ[handler],
        (* then attempt to extract the one indicated in the handler spec string *)
        Which[
            (* there's no handler function name *)
            !StringQ[handlerName],
                Return@Failure["NoHandlerName", <|
                    "MessageTemplate" -> StringJoin[
                        "The handler file returned a set of multiple handler functions (`functionNames`), ",
                        "but the supplied handler string \"`handlerSpec`\" does not indicate a ",
                        "function by name; try giving a handler string like ",
                        "\"`handlerFileBaseName`.`firstFunctionName`\""
                    ],
                    "MessageParameters" -> <|
                        "functionNames" -> ToString[Keys@handler, InputForm],
                        "handlerSpec" -> handlerSpec,
                        "handlerFileBaseName" -> handlerFileBaseName,
                        "firstFunctionName" -> First@Keys[handler]
                    |>
                |>],

            (* the specified function name doesn't exist *)
            !KeyExistsQ[handler, handlerName],
                Return@Failure["NamedHandlerMissing", <|
                    "MessageTemplate" -> StringJoin[
                        "The set of handler functions (`functionNames`) returned by the handler file does not ",
                        "include the named function \"`handlerName`\""
                    ],
                    "MessageParameters" -> <|
                        "functionNames" -> StringRiffle[Keys@handler, ", "],
                        "handlerName" -> handlerName
                    |>
                |>]
        ];

        handler = handler[handlerName]
    ];

    Return[handler];
]

(* ::Subsubsection:: *)
(* Sanitize/validate the return value from a handler file *)

sanitizeHandler[f_APIFunction] := f

sanitizeHandler[
    ExternalBundle[items:(_Association | {Rule[_String, _]..}), ___]
] := sanitizeHandler[items]

sanitizeHandler[rules:{Rule[_String, _]..}] := sanitizeHandler[<|rules|>]

sanitizeHandler[assoc_Association?(And[
    AllTrue[Keys[#], StringQ],
    MatchQ[Values[#], {__APIFunction}]
] &)] := assoc

sanitizeHandler[Null] := Failure["NullHandler", <|
    "MessageTemplate" -> StringJoin[{
        "The handler file did not return an APIFunction expression or an association ",
        "or ExternalBundle expression consisting of APIFunction expressions"
    }]
|>]

sanitizeHandler[expr_] := Failure["InvalidHandler", <|
    "MessageTemplate" -> StringJoin[{
        "The expression with head `1` returned from the handler file is neither an APIFunction ",
        "expression nor an association or ExternalBundle expression with string keys and ",
        "APIFunction expressions as values"
    }],
    "MessageParameters" -> {Head[expr]}
|>]

(* handle weird things like Sequence *)
sanitizeHandler[___] := sanitizeHandler[Null]

(* ::Subsection:: *)
(* Process an invocation request using the handler *)

processInvocation[
    invocationData_HTTPResponse,
    handler_APIFunction
] := Module[{
    environment = GetEnvironment[],
    parseJSONHeader = (Replace[
        ImportString[#, "RawJSON"],
        assoc_Association :> KeyMap[Capitalize, assoc],
        All
    ] &),
    requestHeaders,
    requestID,

    requestBody,
    requestContextData,

    outputSpec,
    handlerOutput
},
    requestHeaders = invocationData["Headers"];
    requestID = Lookup[
        requestHeaders,
        ToLowerCase["Lambda-Runtime-Aws-Request-Id"]
    ];

    If[
        !StringQ[requestID],
        Print["RUNTIME ERROR: Could not get request ID"];
        Exit[44];
    ];

    requestBody = ImportByteArray[
        invocationData["BodyByteArray"],
        "RawJSON"
    ];

    If[
        (* if the request didn't parse *)
        !AssociationQ[requestBody],
        (* then emit an error and return to the main loop *)
        sendInvocationError[
            requestID,
            Failure["InvocationParseFailure", <|
                "MessageTemplate" -> "Failed to parse request payload as JSON"
            |>]
        ];
        Return[]
    ];

    requestContextData = KeySort@<|
        "AWSRequestID" -> requestID,

        (* header data *)

        "ExecutionDeadline" -> Lookup[
            requestHeaders,
            ToLowerCase["Lambda-Runtime-Deadline-Ms"],
            Missing["NotAvailable"],
            FromUnixTime[FromDigits[#] / 1000] &
        ],
        "InvokedFunctionARN" -> Lookup[
            requestHeaders,
            ToLowerCase["Lambda-Runtime-Invoked-Function-Arn"],
            Missing["NotAvailable"]
        ],
        "ClientContext" -> Lookup[
            requestHeaders,
            ToLowerCase["Lambda-Runtime-Client-Context"],
            Missing["NotAvailable"],
            parseJSONHeader
        ],
        "CognitoIdentity" -> Lookup[
            requestHeaders,
            ToLowerCase["Lambda-Runtime-Cognito-Identity"],
            Missing["NotAvailable"],
            parseJSONHeader
        ],


        (* process environment data *)

        "FunctionName" -> Lookup[
            environment,
            "AWS_LAMBDA_FUNCTION_NAME",
            Missing["NotAvailable"]
        ],
        "FunctionVersion" -> Lookup[
            environment,
            "AWS_LAMBDA_FUNCTION_VERSION",
            Missing["NotAvailable"]
        ],
        "MemoryLimit" -> Lookup[
            environment,
            "AWS_LAMBDA_FUNCTION_MEMORY_SIZE",
            Missing["NotAvailable"],
            Quantity[FromDigits[#], "Megabytes"] &
        ],
        "LogGroupName" -> Lookup[
            environment,
            "AWS_LAMBDA_LOG_GROUP_NAME",
            Missing["NotAvailable"]
        ],
        "LogStreamName" -> Lookup[
            environment,
            "AWS_LAMBDA_LOG_STREAM_NAME",
            Missing["NotAvailable"]
        ]
    |>;
    Echo[requestContextData, "Request context data"];


    SetEnvironment[
        "_X_AMZN_TRACE_ID" -> Lookup[
            requestHeaders,
            ToLowerCase["Lambda-Runtime-Trace-Id"],
            None
        ]
    ];

    handlerOutput = Block[{
        System`$AWSLambdaContextData = requestContextData
    },
        withCleanContext[handler[requestBody]]
    ];

    If[
        (* if the APIFunction indicates an output form *)
        Length[handler] >= 3,
        (* then wrap the output appropriately *)
        outputSpec = handler[[3]];
        handlerOutput = Switch[outputSpec,
            _String,
                handlerOutput = ExportForm[
                    handlerOutput,
                    outputSpec
                ]
        ]
    ];

    sendInvocationResponse[requestID, handlerOutput];
]

(* ::Section:: *)
(* API requests *)

(* ::Subsection:: *)
(* Long-poll for next invocation *)

getNextInvocation[] := Module[{
    request,
    response
},
    request = buildAPIRequest[<|
        "Method" -> "GET",
        "Path" -> "runtime/invocation/next"
    |>];
    response = handleAPIResponseError@URLRead[
        request,
        TimeConstraint -> Infinity
    ];
    Echo[response, "received"];

    If[
        (* if the request failed *)
        FailureQ[response],
        (* then print an error and exit (to avoid
            getting stuck in an infinite loop) *)
        Print["RUNTIME ERROR: " <> response["Message"]];
        Exit[43];
    ];

    Return[response]
]

(* ::Subsection:: *)
(* Send invocation response *)

(* ::Subsubsection:: *)
(* Verbatim ByteArray *)

sendInvocationResponse[requestID_String, data_ByteArray] := Module[{
    request
},
    request = buildAPIRequest[<|
        "Method" -> "POST",
        "Path" -> {"runtime/invocation", requestID, "response"},
        "Body" -> data
    |>];
    Echo[request, "sending"];

    response = handleAPIResponseError@URLRead[request];
    Echo[response, "received"];

    If[
        FailureQ[response],
        Print["RUNTIME ERROR: " <> response["Message"]]
    ];
]

(* ::Subsubsection:: *)
(* Verbatim string *)

sendInvocationResponse[
    requestID_String,
    str_String
] := sendInvocationResponse[
    requestID,
    StringToByteArray[str]
]

(* ::Subsubsection:: *)
(* Failure (to invocation error) *)

sendInvocationResponse[
    requestID_String,
    failure_Failure
] := sendInvocationError[requestID, failure]

(* ::Subsubsection:: *)
(* ExportForm wrapper (for GenerateHTTPResponse) *)

sendInvocationResponse[
    requestID_String,
    wrapper:ExportForm[expr_, format_, ___]
] := Module[{
    responseBytes = GenerateHTTPResponse[wrapper]["BodyByteArray"]
},
    If[
        (* if the handler output was successfully serialized *)
        ByteArrayQ[responseBytes],
        (* then send it *)
        sendInvocationResponse[requestID, responseBytes],
        (* else send an error *)
        sendInvocationError[
            requestID,
            Failure["SerializationFailure", <|
                "MessageTemplate" -> StringJoin[{
                    "Handler output expression with head `head` could not ",
                    "be exported to format `format`"
                }],
                "MessageParameters" -> <|
                    "head" -> ToString[Head[expr], InputForm],
                    "format" -> ToString[Head[format], InputForm]
                |>
            |>]
        ]
    ]
]

(* ::Subsubsection:: *)
(* Arbitrary expression (to JSON) *)

sendInvocationResponse[requestID_String, expr_] := Module[{
    responseBytes = ExportByteArray[
        expr,
        "RawJSON",
        "Compact" -> True
    ]
},
    If[
        (* if the handler output was successfully serialized to JSON *)
        ByteArrayQ[responseBytes],
        (* then send it *)
        sendInvocationResponse[requestID, responseBytes],
        (* else send an error *)
        sendInvocationError[
            requestID,
            Failure["SerializationFailure", <|
                "MessageTemplate" -> StringJoin[{
                    "Handler output expression with head `head` could not ",
                    "be serialized to JSON"
                }],
                "MessageParameters" -> <|
                    "head" -> ToString[Head[expr], InputForm]
                |>
            |>]
        ]
    ]
]

(* ::Subsection:: *)
(* Runtime initialization error *)

sendInvocationError[requestID_String, failure_Failure] := Module[{
    request,
    response
},
    request = buildAPIRequest[<|
        "Method" -> "POST",
        "Path" -> {"runtime/invocation", requestID, "error"},
        failureToErrorRequest[failure]
    |>];
    Echo[request, "sending"];

    response = handleAPIResponseError@URLRead[request];
    Echo[response, "received"];

    If[
        FailureQ[response],
        Print["RUNTIME ERROR: " <> response["Message"]]
    ];
]

(* ::Subsection:: *)
(* Runtime initialization error (send and immediately exit) *)

exitWithInitializationError[failure_Failure] := Module[{
    request,
    response
},
    Print["RUNTIME ERROR: " <> failure["Message"]];
    request = buildAPIRequest[<|
        "Method" -> "POST",
        "Path" -> "runtime/init/error",
        failureToErrorRequest[failure]
    |>];
    Echo[request, "sending"];
    response = handleAPIResponseError@URLRead[request];
    Echo[response, "received"];
    Exit[41]
]

exitWithInitializationError[___] := exitWithInitializationError[
    Failure["UnknownFailure", <|
        "MessageTemplate" -> "An unknown failure occurred."
    |>]
]

(* ::Section:: *)
(* Utilities *)

(* ::Subsection:: *)
(* buildAPIRequest - build an HTTPRequest to the runtime API endpoint *)

buildAPIRequest[requestData_Association] := Module[{},
    Return@HTTPRequest[<|
        requestData,
        "Scheme" -> "http",
        "Domain" -> $LambdaRuntimeAPIHost,
        "Path" -> Flatten@{
            $LambdaRuntimeAPIVersion,
            Lookup[requestData, "Path", {}]
        }
    |>]
]

(* ::Subsection:: *)
(* failureToErrorRequest - convert a Failure expression into request parameters *)

failureToErrorRequest[failure_Failure] := Module[{
    failureTag = Replace[
        failure["Tag"],
        Except[_String] -> "UnknownFailure"
    ]
},
    Return@<|
        "ContentType" -> "application/vnd.aws.lambda.error+json",
        "Headers" -> <|
            "Lambda-Runtime-Function-Error-Type" -> failureTag
        |>,
        "Body" -> ExportByteArray[<|
            "errorType" -> failureTag,
            "errorMessage" -> ToString@Replace[
                failure["Message"],
                Except[_String] -> "An unknown failure occurred."
            ]
        |>, "RawJSON"]
    |>
]


(* ::Subsection:: *)
(* errorResponseToFailure - convert a JSON error response to a Failure *)

errorResponseToFailure[response_HTTPResponse] := Module[{
    errorData = Replace[
        Quiet@ImportByteArray[response["BodyByteArray"], "RawJSON"],

        (* handle a failed parse *)
        Except[_Association] -> <|
            "errorMessage" -> Replace[
                StringTrim[response["Body"]],
                ("" | Except[_String]) -> "Unknown error"
            ],
            "errorType" -> "UnknownError"
        |>
    ]
},
    Return@Failure[
        Lookup[errorData, "errorType", "UnknownError"],
        <|
            "MessageTemplate" -> "`message` (code `code`)",
            "MessageParameters" -> <|
                "message" -> Lookup[errorData, "errorMessage", "Unknown error"],
                "code" -> response["StatusCode"]
            |>,
            "StatusCode" -> response["StatusCode"]
        |>
    ]
]

(* ::Subsection:: *)
(* handleAPIResponseError - catch error responses based on status code; pass through success *)

handleAPIResponseError[response_HTTPResponse] := Switch[
    response["StatusCode"],

    _Integer?(Between[{200, 299}]),
        Return[response],
    
    (* per API spec: "Container error. Non-recoverable state.
        Runtime should exit promptly." *)
    500,
        Print@StringTemplate[
            "RUNTIME ERROR: Non-recoverable container error (code `1`)"
        ][response["StatusCode"]];
        If[
            (* if there's a nonempty response body *)
            StringLength[response["Body"]] > 0,
            (* then print it *)
            Print[response["Body"]]
        ];
        Exit[42],

    400 | 403 | 413,
        Return[errorResponseToFailure[response]],
    
    _,
        Return@Failure["UnknownStatusCode", <|
            "MessageTemplate" -> "Unknown response status code `1`",
            "MessageParameters" -> {response["StatusCode"]}
        |>]
]

(* Failure from URLRead *)
handleAPIResponseError[failure_Failure] := failure

(* ::Subsection:: *)
(* withCleanContext - evaluate an expression with clean $Context and $ContextPath *)

SetAttributes[withCleanContext, HoldFirst]
withCleanContext[expr_] := Block[{
    $Context = "Global`",
    $ContextPath = {"System`", "Global`"}
},
    expr
]

End[]

EndPackage[]