BeginPackage["AWSLambdaRuntime`Modes`Raw`"]

AWSLambdaRuntime`Modes`ValidateHandler
AWSLambdaRuntime`Modes`EvaluateHandler

Begin["`Private`"]

Needs["AWSLambdaRuntime`API`"]
Needs["AWSLambdaRuntime`Utility`"]

(* ::Section:: *)
(* Validate handler (called during initialization) *)

(* valid *)
AWSLambdaRuntime`Modes`ValidateHandler[
    "HTTP",
    handler_
] := Success["Valid", <||>]

(* ::Section:: *)
(* Evaluate handler *)

AWSLambdaRuntime`Modes`EvaluateHandler[
    "HTTP",
    handler_,
    requestBody_,
    requestContextData_
] := Module[{
    httpRequest,
    rawRequestMetadata,

    requesterIPAddress,
    requestUserAgent,
    apiGatewayRequestID,

    pathParameters,
    dispatchPathString,

    httpRequestData,

    httpResponse
},
    If[
        !Association[requestBody],
        Return@Failure["InvalidRequestBody", <|
            "MessageTemplate" -> "The request is not in the expected proxy request format"
        |>]
    ];

    httpRequest = AWSLambdaRuntime`Utility`ProxyFormatToHTTPRequest[
        requestBody
    ];

    (* raw data to make available to the handler *)
    rawRequestMetadata = KeyDrop[requestBody, "body"];

    requesterIPAddress = Replace[
        requestBody["requestContext", "identity", "sourceIp"],
        Except[_String] -> None
    ];
    requestUserAgent = SelectFirst[
        {
            Lookup[
                (* check the raw headers because "UserAgent"
                    defaults to "Wolfram HTTPClient" *)
                httpRequest["RawLowerHeaders"],
                "user-agent"
            ],

            requestBody["requestContext", "identity", "userAgent"]
        },
        StringQ,
        None
    ];
    apiGatewayRequestID = Replace[
        requestBody["requestContext", "requestId"],
        Except[_String] -> None
    ];


    pathParameters = Lookup[
        requestBody,
        "pathParameters",
        <||>
    ] // Replace[Null -> <||>];

    dispatchPathString = Lookup[
        pathParameters,
        First[
            StringCases[
                Lookup[requestBody, "resource", "/"],
                "{" ~~ paramName:(Except["}"]..) ~~ "+}" :> paramName
            ],
            None
        ],
        "/"
    ] // Replace[Except[_String] -> "/"] // URLDecode;

    (* prepend a slash if there isn't one already *)
    If[
        !StringStartsQ[dispatchPathString, "/"],
        dispatchPathString = "/" <> dispatchPathString
    ];


    (* for second argument of GenerateHTTPResponse *)
    httpRequestData = <|
        (* extract the relevant properties of the HTTPRequest *)
        httpRequest[{
            "Method",
            "Scheme", "User", "Domain", "Port", "PathString", "QueryString", "Fragment",
            "Cookies",
            "BodyByteArray"
        }],

        "DispatchPathString" -> dispatchPathString,

        (* avoid the auto-inserted user-agent header in "Headers" *)
        "Headers" -> httpRequest["RawHeaders"],

        "MultipartElements" -> Switch[
            ToLowerCase[httpRequest["ContentType"]],

            "application/x-www-form-urlencoded",
                Replace[
                    URLQueryDecode@ByteArrayToString[httpRequest["BodyByteArray"]],
                    Except[{__Rule}] -> {}
                ] // Map@Apply[#1 -> <|
                    "ContentString" -> #2,
                    "InMemory" -> True
                |> &],

            _,
                None
        ],

        "RequesterAddress" -> requesterIPAddress,
        "SessionID" -> apiGatewayRequestID,
        
        "AWSLambdaContextData" -> requestContextData,
        "AWSLambdaRawRequestMetadata" -> rawRequestMetadata
    |>;


    httpResponse = With[{
        $handler = handler,
        $httpRequestData = httpRequestData
    },
        Block[{
            System`$RequesterAddress = requesterIPAddress,
            System`$UserAgentString = requestUserAgent,
            AWSLambdaRuntime`Handler`$AWSLambdaRawRequestMetadata = rawRequestMetadata
        },
            (* TODO: catch explictly thrown failures (Confirm/Enclose)
                and return them verbatim so they get converted to
                invocation errors *)
            AWSLambdaRuntime`Utility`WithCleanContext@GenerateHTTPResponse[
                $handler,
                $httpRequestData
            ]
        ]
    ];

    Return[httpResponse]
]

End[]

EndPackage[]