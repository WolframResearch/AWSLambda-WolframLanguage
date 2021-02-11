BeginPackage["AWSLambdaRuntime`"]

AWSLambdaRuntime`StartRuntime

Begin["`Private`"]

Block[{$ContextPath},
    Needs["CloudObject`"];
    Needs["CURLLink`"];
    Needs["Forms`"];
]

Needs["AWSLambdaRuntime`API`"]
Needs["AWSLambdaRuntime`Modes`"]
Needs["AWSLambdaRuntime`Utility`"]

logTiming[args___] := Print[DateList[], " ", args]

(* ::Section:: *)
(* Environment variables *)

AWSLambdaRuntime`$LambdaRuntimeAPIHost = Environment["AWS_LAMBDA_RUNTIME_API"]
AWSLambdaRuntime`$LambdaRuntimeAPIVersion = "2018-06-01"


Print["Context info at top of main file: ", ToString[<|
    "Context" -> $Context,
    "ContextPath" -> $ContextPath,
    "Packages" -> Sort@$Packages
|>, InputForm]]

(* ::Section:: *)
(* Handler initialization and main loop *)

AWSLambdaRuntime`StartRuntime[] := Module[{
    handler,
    validateResult,
    invocationData
},
    logTiming["Start of StartRuntime"];
    If[
        (* if the API host is not set *)
        !StringQ[AWSLambdaRuntime`$LambdaRuntimeAPIHost],
        (* then print an error and quit (we can't emit a proper initialization error
            to the API if we don't know what the API host is...) *)
        Print["FATAL RUNTIME ERROR: AWS_LAMBDA_RUNTIME_API environment variable not set"];
        Exit[40];
    ];

    (* load the handler expression from the handler file *)
    logTiming["Loading handler"];
    handler = loadHandler[];
    logTiming["Loaded handler"];

    Print["Context info after loading handler: ", ToString[<|
        "Context" -> $Context,
        "ContextPath" -> $ContextPath,
        "Packages" -> Sort@$Packages
    |>, InputForm]];

    If[
        (* if loadHandler failed *)
        FailureQ[handler],
        (* then emit an error and exit *)
        AWSLambdaRuntime`API`ExitWithInitializationError[handler]
    ];

    validateResult = AWSLambdaRuntime`Modes`ValidateHandler[
        AWSLambdaRuntime`Handler`$AWSLambdaHandlerMode,
        handler
    ];

    If[
        (* if the handler is invalid *)
        FailureQ[validateResult],
        (* then emit an error and exit *)
        AWSLambdaRuntime`API`ExitWithInitializationError[validateResult]
    ];

    logTiming["Starting main loop"];

    (* main loop: long-poll for invocations and process them *)
    While[True,
        invocationData = AWSLambdaRuntime`API`GetNextInvocation[];
        processInvocation[invocationData, handler];
    ];

    Exit[0]
]

(* ::Subsection:: *)
(* Load user handler *)

(* "Raw" or "HTTP";
    used if AWSLambdaRuntime`Handler`$AWSLambdaHandlerMode isn't set *)
$defaultHandlerMode = "Raw"

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
    allowedHandlerFileExtensions = "wl" | "m" | "mx" | "wxf",

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
    AWSLambdaRuntime`Handler`$AWSLambdaHandlerName = handlerName;

    (* can be overridden by handler file initialization code *)
    AWSLambdaRuntime`Handler`$AWSLambdaHandlerMode = Lookup[
        GetEnvironment[],
        "WOLFRAM_LAMBDA_HANDLER_MODE",
        $defaultHandlerMode
    ];

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

    (* load the handler file, allowing any initialization code to run *)
    handlerFileReturnValue = AWSLambdaRuntime`Utility`WithCleanContext[
        Get[handlerFileName]
    ];

    handler = sanitizeHandler[handlerFileReturnValue];

    If[
        (* if the value returned by the handler file is invalid *)
        FailureQ[handler],
        (* then return the corresponding Failure *)
        Return[handler]
    ];

    If[
        (* if the handler file returned a set of multiple handlers *)
        AssociationQ[handler],
        (* then attempt to extract the one indicated in the handler spec string *)
        Which[
            (* there's no handler expression name *)
            !StringQ[handlerName],
                Return@Failure["NoHandlerName", <|
                    "MessageTemplate" -> StringJoin[
                        "The handler file returned a set of multiple handler expression ",
                        "(`handlerNames`), but the supplied handler string \"`handlerSpec`\" ",
                        "does not indicate a handler by name; try giving a handler string ",
                        "like \"`handlerFileBaseName`.`firstHandlerName`\""
                    ],
                    "MessageParameters" -> <|
                        "handlerNames" -> ToString[Keys@handler, InputForm],
                        "handlerSpec" -> handlerSpec,
                        "handlerFileBaseName" -> handlerFileBaseName,
                        "firstHandlerName" -> First@Keys[handler]
                    |>
                |>],

            (* the specified handler name doesn't exist *)
            !KeyExistsQ[handler, handlerName],
                Return@Failure["NamedHandlerMissing", <|
                    "MessageTemplate" -> StringJoin[
                        "The set of handler expressions (`handlerNames`) returned by the handler file does not ",
                        "include the named handler \"`handlerName`\""
                    ],
                    "MessageParameters" -> <|
                        "handlerNames" -> StringRiffle[Keys@handler, ", "],
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

sanitizeHandler[rules:{__Rule}] := sanitizeHandler[<|rules|>]

sanitizeHandler[assoc_Association?(And[
    Length[#] > 0,
    AllTrue[Keys[#], StringQ]
] &)] := assoc

sanitizeHandler[assoc_Association] := Failure["InvalidHandler", <|
    "MessageTemplate" -> StringJoin[{
        "The association returned by the handler file is empty or ",
        "does not have strings as keys"
    }]
|>]

sanitizeHandler[Null] := Failure["NullHandler", <|
    "MessageTemplate" -> StringJoin[{
        "The handler file did not return an expression or ",
        "association of expressions"
    }]
|>]

sanitizeHandler[handler_] := handler

(* handle weird things like Sequence *)
sanitizeHandler[___] := sanitizeHandler[Null]

(* ::Subsection:: *)
(* Process an invocation request using the handler *)

processInvocation[
    invocationData_HTTPResponse,
    handler_
] := Module[{
    environment = GetEnvironment[],
    parseJSONHeader = (AWSLambdaRuntime`Utility`CapitalizeAllKeys[
        ImportString[#, "RawJSON"]
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
        AWSLambdaRuntime`API`SendInvocationError[
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
        "LogGroupName" -> Lookup[
            environment,
            "AWS_LAMBDA_LOG_GROUP_NAME",
            Missing["NotAvailable"]
        ],
        "LogStreamName" -> Lookup[
            environment,
            "AWS_LAMBDA_LOG_STREAM_NAME",
            Missing["NotAvailable"]
        ],

        (* delayed rule to avoid causing QuantityUnits` to load *)
        Lookup[
            environment,
            "AWS_LAMBDA_FUNCTION_MEMORY_SIZE",
            "MemoryLimit" -> Missing["NotAvailable"],
            With[{n = FromDigits[#]},
                "MemoryLimit" :> Quantity[n, "Megabytes"]
            ] &
        ]
    |>;


    SetEnvironment[
        "_X_AMZN_TRACE_ID" -> Lookup[
            requestHeaders,
            ToLowerCase["Lambda-Runtime-Trace-Id"],
            None
        ]
    ];

    logTiming["Before evaluating handler"];
    handlerOutput = Block[{
        AWSLambdaRuntime`Handler`$AWSLambdaContextData = requestContextData
    },
        AWSLambdaRuntime`Modes`EvaluateHandler[
            AWSLambdaRuntime`Handler`$AWSLambdaHandlerMode,
            handler,
            requestBody,
            requestContextData
        ]
    ];
    logTiming["After evaluating handler"];

    Print["Context info after evaluating handler: ", ToString[<|
        "Context" -> $Context,
        "ContextPath" -> $ContextPath,
        "Packages" -> Sort@$Packages
    |>, InputForm]];

    AWSLambdaRuntime`API`SendInvocationResponse[requestID, handlerOutput];
]


End[]

EndPackage[]