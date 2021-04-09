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
    Needs["MIMETools`"];
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
    mimeMessage,
    requestContentType,
    requestParts,
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

    mimeMessage = MIMETools`MIMEMessageOpen[
        ByteArrayToString[
            Join[
                ByteArray[requestHeaderBytes],
                request["BodyByteArray"]
            ],
            "ISO8859-1"
        ]
    ] // checkMIMEToolsException;

    If[
        (* if we couldn't open the message *)
        Head[mimeMessage] =!= MIMETools`MIMEMessage,
        (* then return None *)
        Return[None]
    ];

    requestContentType = MIMETools`MIMEMessageRead[
        mimeMessage,
        "MessageContentType"
    ] // checkMIMEToolsException;

    Which[
        (* if we couldn't check the Content-Type *)
        !StringQ[requestContentType],
        (* then return None *)
        MIMETools`MIMEMessageClose[mimeMessage];
        Return[None],


        (* if the request is not multipart *)
        !TrueQ@StringStartsQ[
            requestContentType,
            "multipart",
            IgnoreCase -> True
        ],
        (* then return None *)
        MIMETools`MIMEMessageClose[mimeMessage];
        Return[None]
    ];

    requestParts = MIMETools`MIMEMessageRead[
        mimeMessage,
        "DecodedRawAttachments"
    ];
    MIMETools`MIMEMessageClose[mimeMessage];

    If[
        (* if we couldn't get the body parts *)
        !ListQ[requestParts],
        (* then return None *)
        Return[None]
    ];

    defaultEncoding = getFormDataDefaultEncoding[requestParts];

    multipartElements = Select[
        parseMultipartFormElement[
            #,
            "DefaultCharacterEncoding" -> Replace[defaultEncoding, Except[_String] -> None]
        ] & /@ requestParts,
        AssociationQ (* parseMultipartFormElement returns None if the element is unusable or irrelevant *)
    ];

    (* convert from list of associations into the format GenerateHTTPResponse expects *)
    multipartElements = #FieldName -> # & /@ multipartElements;

    Return[multipartElements]
]


(* ::Subsubsection:: *)
(* checkMIMEToolsException - handle MIMETools exceptions *)

checkMIMEToolsException[exception_MIMETools`MIMEToolsException] := (
    Print["Runtime encountered MIMETools exception: ", InputForm[exception]];
    $Failed
)

checkMIMEToolsException[expr_] := expr


(* ::Subsubsection:: *)
(* getFormDataDefaultEncoding - get the encoding of a form's fields as indicated by the "_charset_" field *)

getFormDataDefaultEncoding[bodyParts_List] := Module[{
    charsetPart = SelectFirst[
        bodyParts,
        And[
            #["Name"] === "_charset_",
            !StringQ[#["FileName"]], (* field is form field, not uploaded file *)
            StringQ[#["Contents"]], (* has a body *)
            StringLength[#["Contents"]] < 50 (* the body isn't not unexpectedly long *)
        ] &,
        None
    ]
},
    If[
        !AssociationQ[charsetPart],
        Return[None]
    ];

    Return@Replace[
        CloudObject`ToCharacterEncoding[charsetPart["Contents"], None],
        Except[_String] -> None
    ]
]


(* ::Subsubsection:: *)
(* parseMultipartFormElement - parse one MIME entity representing a form field *)

Options[parseMultipartFormElement] = {"DefaultCharacterEncoding" -> None}

parseMultipartFormElement[rawEntity_Association, OptionsPattern[]] := Module[{
    contentType = rawEntity["ContentType"],
    fieldName = rawEntity["Name"],
    originalFileName = Lookup[rawEntity, "FileName", None],

    bodyByteArray,

    isFormField,
    contentTypeEncoding,
    bodyString,

    elementData
},
    If[
        (* if the required "name" field is missing *)
        !StringQ[fieldName],
        (* then return None (such elements will get filtered out later) *)
        Return[None]
    ];

    bodyByteArray = StringToByteArray[
        Lookup[rawEntity, "Contents", ""],
        "ISO8859-1"
    ];

    isFormField = !StringQ[originalFileName];

    If[
        (* if the part is a form field (rather than an uploaded file) *)
        isFormField,

        (* then look for an indicated charset and use it to decode the body *)
        contentTypeEncoding = Lookup[
            rawEntity,
            "CharacterEncoding",
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
        "ContentType" -> contentType,
        "OriginalFileName" -> originalFileName,
        "ByteCount" -> Length[bodyByteArray],
        "FormField" -> isFormField,
        "InMemory" -> True
    |>;

    Return[elementData]
]

End[]

EndPackage[]