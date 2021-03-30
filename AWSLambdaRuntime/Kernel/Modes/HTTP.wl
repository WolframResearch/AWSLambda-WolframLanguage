BeginPackage["AWSLambdaRuntime`Modes`HTTP`"]

AWSLambdaRuntime`Modes`ValidateHandler
AWSLambdaRuntime`Modes`EvaluateHandler

Begin["`Private`"]

Needs["AWSLambdaRuntime`API`"]
Needs["AWSLambdaRuntime`Utility`"]

(* ::Section:: *)
(* Initialize mode implementation (load dependencies) *)

AWSLambdaRuntime`Modes`InitializeMode["HTTP"] := (
    Needs["Forms`"];
    Needs["MimeticLink`"];
)

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

        "Parameters" -> Join[
            httpRequest["Query"] // Replace[Except[_List] -> {}],
            parseHTTPRequestURLEncodedParameters[httpRequest]
        ],

        "MultipartElements" -> parseHTTPRequestMultipartElements[httpRequest],

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


(* ::Section:: *)
(* Request body parsing *)

(* ::Subsection:: *)
(* URL-encoded requests *)

(* ::Subsubsection:: *)
(* parseHTTPRequestURLEncodedParameters - parse the URL-encoded body of an HTTPRequest into a list, or {} if not applicable *)

parseHTTPRequestURLEncodedParameters[request_HTTPRequest] := Module[{
    parameters
},
    If[
        (* if the Content-Type isn't application/x-www-form-urlencoded *)
        !And[
            StringQ[request["ContentType"]],
            StringStartsQ[request["ContentType"], "application/x-www-form-urlencoded"]
        ],
        (* then return None *)
        Return@{}
    ];

    parameters = URLQueryDecode@ByteArrayToString[request["BodyByteArray"]];

    Return@Switch[parameters,
        {Rule[_String, _String] ..},
            parameters,

        _,
            {}
    ]
]

(* ::Subsection:: *)
(* Multipart requests *)

(* ::Subsubsection:: *)
(* httpRequestIsMultipartQ - return whether an HTTPRequest's Content-Type is multipart *)

httpRequestIsMultipartQ[request_HTTPRequest] := TrueQ@And[
    StringQ[request["ContentType"]],
    StringStartsQ[ToLowerCase[request["ContentType"]], "multipart"]
]

(* ::Subsubsection:: *)
(* parseHTTPRequestMultipartElements - parse the body of an HTTPRequest into a MultipartElements list, or None if not applicable *)

parseHTTPRequestMultipartElements[request_HTTPRequest] := Module[{
    requestHeaderBytes,
    parsedBody,
    childParts,
    defaultEncoding,
    multipartElements
},
    If[
        (* if the request doesn't look like a nonempty multipart request *)
        Or[
            !httpRequestIsMultipartQ[request],
            !ByteArrayQ[request["BodyByteArray"]] (* catches "empty ByteArrays" *)
        ],
        (* then return None *)
        Return[None]
    ];

    requestHeaderBytes = StringToByteArray[
        StringJoin[
            Map[
                StringRiffle[
                    Replace[List @@ #, Except[_String] -> "", 1],
                    {"", ": ", "\r\n"}
                ] &,
                request["RawHeaders"]
            ]
        ] <> "\r\n",
        "ISO8859-1"
    ];

    parsedBody = MimeticLink`ParseMIMEByteArray@Join[
        ByteArray[requestHeaderBytes],
        request["BodyByteArray"]
    ];

    If[
        (* if the request is not multipart *)
        !And[
            AssociationQ[parsedBody],
            parsedBody["IsMultipart"] === True
        ],
        (* then return None *)
        Return[None]
    ];

    childParts = Lookup[parsedBody, "ChildParts", {}];
    defaultEncoding = getFormDataDefaultEncoding[childParts];

    multipartElements = Select[
        parseMultipartFormElement[
            #,
            "DefaultCharacterEncoding" -> Replace[defaultEncoding, Except[_String] -> None]
        ] & /@ childParts,
        AssociationQ (* parseMultipartFormElement returns None if the element is unusable or irrelevant *)
    ];

    (* convert from list of associations into the format GenerateHTTPResponse expects *)
    multipartElements = #FieldName -> # & /@ multipartElements;

    Return[multipartElements]
]


(* ::Subsubsection:: *)
(* getFormDataDefaultEncoding - get the encoding of a form's fields as indicated by the "_charset_" field *)

getFormDataDefaultEncoding[bodyParts_List] := Module[{
    charsetPart = SelectFirst[
        bodyParts,
        And[
            #["ContentDisposition", "Parameters", "name"] === "_charset_",
            !StringQ[#["ContentDisposition", "Parameters", "filename"]], (* field is form field *)
            Length[#BodyByteArray] < 50 (* not unexpectedly long *)
        ] &,
        None
    ],
    charsetString,
    characterEncodingString
},
    If[
        !AssociationQ[charsetPart],
        Return[None]
    ];

    charsetString = ByteArrayToString[charsetPart["BodyByteArray"], "ISO8859-1"];
    characterEncodingString = CloudObject`ToCharacterEncoding[charsetString, None];

    Return@Replace[characterEncodingString, Except[_String] -> None]
]


(* ::Subsubsection:: *)
(* parseMultipartFormElement - parse one MIME entity representing a form field *)

Options[parseMultipartFormElement] = {"DefaultCharacterEncoding" -> None}

parseMultipartFormElement[rawEntity_Association, OptionsPattern[]] := Module[{
    contentType = Lookup[rawEntity, "ContentType", <||>, Replace[_Missing -> <||>]],
    dispositionParameters = Lookup[
        Lookup[rawEntity, "ContentDisposition", <||>],
        "Parameters",
        <||>
    ],
    fieldName,
    originalFileName,
    isFormField,
    bodyByteArray,
    contentTypeEncoding,
    bodyString,
    elementData
},

    fieldName = dispositionParameters["name"];
    If[
        (* if the required "name" field is missing *)
        !StringQ[fieldName],
        (* then return None (such elements will get filtered out later) *)
        Return[None]
    ];

    originalFileName = Lookup[dispositionParameters, "filename", None];
    isFormField = !StringQ[originalFileName];

    bodyByteArray = Lookup[rawEntity, "BodyByteArray", {}];

    If[
        (* if the part is a form field (rather than an uploaded file) *)
        isFormField,

        (* then look for an indicated charset and use it to decode the body *)
        contentTypeEncoding = Lookup[
            Lookup[contentType, "Parameters", <||>],
            "charset",
            OptionValue["DefaultCharacterEncoding"],
            CloudObject`ToCharacterEncoding[#, None] &
        ];

        If[
            (* if an encoding was specified *)
            StringQ[contentTypeEncoding],
            (* then try to decode the body *)
            bodyString = ByteArrayToString[bodyByteArray, contentTypeEncoding];
        ];
    ];

    (* TODO: support writing bodies above some configurable threshold to temp files *)
    elementData = <|
        (* if a string was decoded, then use it; otherwise use the raw ByteArray *)
        "ContentString" -> If[StringQ[bodyString], bodyString, bodyByteArray],

        "FieldName" -> fieldName,
        "ContentType" -> Lookup[contentType, "Raw", None],
        "OriginalFileName" -> originalFileName,
        "ByteCount" -> Length[bodyByteArray],
        "FormField" -> isFormField,
        "InMemory" -> True
    |>;

    Return[elementData]
]

End[]

EndPackage[]