BeginPackage["AWSLambdaRuntime`API`"]

AWSLambdaRuntime`API`GetNextInvocation
AWSLambdaRuntime`API`SendInvocationResponse
AWSLambdaRuntime`API`SendInvocationError
AWSLambdaRuntime`API`ExitWithInitializationError

Begin["`Private`"]

Needs["AWSLambdaRuntime`Utility`"]

(* ::Section:: *)
(* API requests *)

(* ::Subsection:: *)
(* Long-poll for next invocation *)

AWSLambdaRuntime`API`GetNextInvocation[] := Module[{
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
    Echo[response, {DateList[], "received"}];

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

(* TODO: something about empty ByteArrays being {} *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    data_ByteArray
] := Module[{
    request
},
    request = buildAPIRequest[<|
        "Method" -> "POST",
        "Path" -> {"runtime/invocation", requestID, "response"},
        "Body" -> data
    |>];
    Echo[request, {DateList[], "sending"}];

    response = handleAPIResponseError@URLRead[request];
    Echo[response, {DateList[], "received"}];

    If[
        FailureQ[response],
        Print["RUNTIME ERROR: " <> response["Message"]]
    ];
]

(* ::Subsubsection:: *)
(* Verbatim string *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    str_String
] := AWSLambdaRuntime`API`SendInvocationResponse[
    requestID,
    StringToByteArray[str]
]

(* ::Subsubsection:: *)
(* Failure (to invocation error) *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    failure_Failure
] := AWSLambdaRuntime`API`SendInvocationError[requestID, failure]

(* ::Subsubsection:: *)
(* ExportForm wrapper (for GenerateHTTPResponse) *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    wrapper:ExportForm[expr_, format_, ___]
] := Module[{
    responseBytes = GenerateHTTPResponse[wrapper]["BodyByteArray"]
},
    If[
        (* if the handler output was successfully serialized *)
        ByteArrayQ[responseBytes],
        (* then send it *)
        AWSLambdaRuntime`API`SendInvocationResponse[
            requestID,
            responseBytes
        ],
        (* else send an error *)
        AWSLambdaRuntime`API`SendInvocationError[
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
(* HTTPRedirect/HTTPErrorResponse (to HTTPResponse) *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    expr:(_HTTPRedirect | _HTTPErrorResponse)
] := AWSLambdaRuntime`API`SendInvocationResponse[
    requestID,
    GenerateHTTPResponse[expr]
]

(* ::Subsubsection:: *)
(* HTTPResponse (to API Gateway proxy response format JSON) *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    response_HTTPResponse
] := AWSLambdaRuntime`API`SendInvocationResponse[
    requestID,
    AWSLambdaRuntime`Utility`HTTPResponseToProxyFormat[response]
]

(* ::Subsubsection:: *)
(* Arbitrary expression (to JSON) *)

AWSLambdaRuntime`API`SendInvocationResponse[
    requestID_String,
    expr_
] := Module[{
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
        AWSLambdaRuntime`API`SendInvocationResponse[
            requestID,
            responseBytes
        ],
        (* else send an error *)
        AWSLambdaRuntime`API`SendInvocationError[
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

AWSLambdaRuntime`API`SendInvocationError[
    requestID_String,
    failure_Failure
] := Module[{
    request,
    response
},
    request = buildAPIRequest[<|
        "Method" -> "POST",
        "Path" -> {"runtime/invocation", requestID, "error"},
        failureToErrorRequest[failure]
    |>];
    Echo[request, {DateList[], "sending"}];

    response = handleAPIResponseError@URLRead[request];
    Echo[response, {DateList[], "received"}];

    If[
        FailureQ[response],
        Print["RUNTIME ERROR: " <> response["Message"]]
    ];
]

(* ::Subsection:: *)
(* Runtime initialization error (send and immediately exit) *)

AWSLambdaRuntime`API`ExitWithInitializationError[
    failure_Failure
] := Module[{
    request,
    response
},
    Print["RUNTIME ERROR: " <> failure["Message"]];
    request = buildAPIRequest[<|
        "Method" -> "POST",
        "Path" -> "runtime/init/error",
        failureToErrorRequest[failure]
    |>];
    Echo[request, {DateList[], "sending"}];
    response = handleAPIResponseError@URLRead[request];
    Echo[response, {DateList[], "received"}];
    Exit[41]
]

AWSLambdaRuntime`API`ExitWithInitializationError[
    ___
] := AWSLambdaRuntime`API`ExitWithInitializationError[
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
        "Domain" -> AWSLambdaRuntime`$LambdaRuntimeAPIHost,
        "Path" -> Flatten@{
            AWSLambdaRuntime`$LambdaRuntimeAPIVersion,
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
(* handleAPIResponseError - catch error responses based on status code; pass through success *)

(* Failure from URLRead *)
handleAPIResponseError[failure_Failure] := failure

(* HTTP response indicating a failure *)
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

End[]

EndPackage[]