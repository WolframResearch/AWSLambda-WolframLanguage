BeginPackage["AWSLambdaRuntime`Utility`"]

AWSLambdaRuntime`Utility`CapitalizeAllKeys
AWSLambdaRuntime`Utility`ProxyFormatToHTTPRequest
AWSLambdaRuntime`Utility`HTTPResponseToProxyFormat
AWSLambdaRuntime`Utility`WithCleanContext

Begin["`Private`"]

AWSLambdaRuntime`Handler`$AWSLambdaUseBinaryResponse = Lookup[
    GetEnvironment[],
    "WOLFRAM_LAMBDA_HTTP_USE_BINARY_RESPONSE"
] =!= "0"

(* ::Subsection:: *)
(* WithCleanContext - evaluate an expression with clean $Context and $ContextPath *)

SetAttributes[AWSLambdaRuntime`Utility`WithCleanContext, HoldFirst]

AWSLambdaRuntime`Utility`WithCleanContext[
    expr_,
    OptionsPattern[{
        "ExtraContexts" -> {"AWSLambdaRuntime`Handler`"}
    }]
] := Block[{
    $Context = "Global`",
    $ContextPath = Join[
        OptionValue["ExtraContexts"],
        {"System`", "Global`"}
    ]
},
    expr
]


(* ::Subsection:: *)
(* CapitalizeAllKeys - recursively capitalize the keys in an association *)

AWSLambdaRuntime`Utility`CapitalizeAllKeys[expr_] := Replace[
    expr,
    assoc_Association :> KeyMap[Capitalize, assoc],
    All
]


(* ::Section:: *)
(* ProxyFormatToHTTPRequest - Convert from the API Gateway proxy integration request format to an HTTPRequest *)

AWSLambdaRuntime`Utility`ProxyFormatToHTTPRequest[
    proxyRequestData_Association
] := Module[{
    headers,
    lowerHeaders
},
    (* flatten out multi-value headers with Thread *)
    headers = Normal@Join[
        (* these keys can have null values *)
        Lookup[proxyRequestData, "headers", <||>, Replace[Null -> <||>]],
        Lookup[proxyRequestData, "multiValueHeaders", <||>, Replace[Null -> <||>]]
    ] // Map[Thread] // Flatten;
    lowerHeaders = KeyMap[ToLowerCase, Association@headers];

    queryParameters = Normal@Join[
        Lookup[proxyRequestData, "queryStringParameters", <||>, Replace[Null -> <||>]],
        Lookup[proxyRequestData, "multiValueQueryStringParameters", <||>, Replace[Null -> <||>]]
    ] // Map[Thread] // Flatten;

    Return@HTTPRequest[
        <|
            "Scheme" -> First[
                (* try to get the protocol from a header; fall back to https *)
                DeleteMissing@Lookup[
                    lowerHeaders,
                    ToLowerCase@{
                        "X-Forwarded-Proto",
                        "CloudFront-Forwarded-Proto"
                    }
                ],
                "https"
            ],
            "User" -> None,
            "Domain" -> SelectFirst[
                (* try to get the domain from requestContext.domainName
                    and then from the Host header *)
                {
                    proxyRequestData["requestContext", "domainName"],
                    lowerHeaders["host"]
                },
                StringQ,
                None
            ],
            "Port" -> None,
            "Path" -> SelectFirst[
                (* try to get the domain from requestContext.path first
                    (it includes the stage name if applicable) *)
                {
                    proxyRequestData["requestContext", "path"],
                    proxyRequestData["path"]
                },
                StringQ,
                None
            ],
            "Query" -> queryParameters,
            "Fragment" -> None
        |>, <|
            "HTTPVersion" -> "1.1", (* TODO: try to get from requestContext.protocol or Via header *)
            "Method" -> Lookup[proxyRequestData, "httpMethod", None],
            "Headers" -> headers,
            "Body" -> If[
                (* if the request body is Base64-encoded *)
                TrueQ[proxyRequestData["isBase64Encoded"]],
                (* then decode it to a ByteArray *)
                BaseDecode[proxyRequestData["body"]],
                (* else keep it as a string *)
                proxyRequestData["body"]
            ]
        |>
    ]
]


(* ::Section:: *)
(* HTTPResponseToProxyFormat - Convert from an HTTPResponse to the API Gateway proxy integration response format *)

AWSLambdaRuntime`Utility`HTTPResponseToProxyFormat[
    httpResponse_HTTPResponse
] := Module[{
    statusCode = httpResponse["StatusCode"],
    headers = httpResponse["CompleteHeaders"],
    bodyByteArray = httpResponse["BodyByteArray"]
},
    If[
        (* if something's fishy about the HTTPResponse properties *)
        !And[
            IntegerQ[statusCode],
            MatchQ[headers, {Rule[_String, _String]...}],
            MatchQ[bodyByteArray, _ByteArray?ByteArrayQ | {}]
        ],
        (* then return a Failure *)
        Return@Failure["InvalidHTTPResponse", <|
            "MessageTemplate" -> "The HTTPResponse expression returned by the handler is not valid"
        |>]
    ];

    Return@<|
        "statusCode" -> statusCode,
        "multiValueHeaders" -> GroupBy[headers, First -> Last],

        If[
            TrueQ@AWSLambdaRuntime`Handler`$AWSLambdaUseBinaryResponse,
            <|
                "body" -> Replace[bodyByteArray, {
                    ba_ByteArray :> BaseEncode[ba],
                    {} -> ""
                }],
                "isBase64Encoded" -> True
            |>,
            <|
                "body" -> ByteArrayToString[bodyByteArray],
                "isBase64Encoded" -> False
            |>
        ]
    |>
]


End[]

EndPackage[]