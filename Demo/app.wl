Echo["Loading app.wl"]

If[
    StringStartsQ[$AWSLambdaHandlerName, "http-"],
    $AWSLambdaHandlerMode = "HTTP"
]


<|

    (* Raw-mode handlers *)

    "pi" -> APIFunction[{
        "digits" -> "Integer" -> 50,
        "base" -> "Integer" -> 10
    }, <|
        "digits" -> RealDigits[Pi, #base, #digits][[1]]
    |> &],

    "divide" -> APIFunction[{
        "dividend" -> "Number",
        "divisor" -> "Number",
        "integer" -> "Boolean" -> False
    }, If[
        TrueQ[#integer],
        AssociationThread[
            {"quotient", "remainder"},
            QuotientRemainder[#dividend, #divisor]
        ],
        <|"quotient" -> #dividend / #divisor|>
    ] &],

    "factor" -> APIFunction[{"x" -> "Integer"}, FactorInteger[#x] &],

    "randomImage" -> APIFunction[
        {"max" -> "Real" -> 1},
        RandomImage[#max] &,
        "PNG"
    ],

    "numberImage" -> APIFunction[{
        "number" -> "Real"
    }, ExportForm[Rasterize[#number, RasterSize -> 100], "PNG"] &],

    "countryPopulation" -> APIFunction[{
        "country" -> "Country",
        "year" -> "Integer" :> DateValue["Year"]
    }, <|
        "population" -> QuantityMagnitude@EntityValue[
            #country,
            Dated["Population", #year]
        ]
    |> &],

    "countryMap" -> APIFunction[
        "country" -> "Country",
        GeoGraphics[Polygon[#country]] &,
        "PNG"
    ],

    "stockPrice" -> APIFunction[
        "ticker" -> "Financial",
        Replace[
            EntityValue[#ticker, "Last"],
            {
                q_Quantity :> <|
                    "magnitude" -> QuantityMagnitude[q],
                    "unit" -> QuantityUnit[q]
                |>,
                n_?NumberQ :> <|"magnitude" -> n|>,
                _ :> Failure["NoData", <|
                    "MessageTemplate" -> "No data found for financial entity \"`1`\"",
                    "MessageParameters" -> {TextString[#ticker]}
                |>]
            }
        ] &
    ],

    "outputJSON" -> APIFunction[<|
        "string" -> "hello world",
        "integer" -> 42,
        "real" -> 123.456,
        "boolean" -> True,
        "null" -> Null,
        "array" -> {1, 2, 3.3, "four"},
        "object" -> <|
            "key1" -> 123,
            "key2" -> "value",
            "key3" -> {3, 1, 4, 1, 5}
        |>
    |> &],

    "outputString" -> APIFunction["this is a string" &],

    "outputWXF" -> APIFunction[{},
        Plot[Sin[x], {x, -5, 5}] &,
        "WXF"
    ],

    "outputMathML" -> APIFunction[{},
        (1 + a) / b &,
        "MathML"
    ],

    "debugData" -> APIFunction[
        ToString[<|
            "Hello" -> "World",
            "Event" -> #,
            "$AWSLambdaHandlerName" -> $AWSLambdaHandlerName,
            "$AWSLambdaHandlerMode" -> $AWSLambdaHandlerMode,
            "$AWSLambdaContextData" -> $AWSLambdaContextData,
            "$AWSLambdaRawRequestMetadata" -> $AWSLambdaRawRequestMetadata,
            "ContextInfo" -> <|
                "$Context" -> $Context,
                "$ContextPath" -> $ContextPath,
                "$Packages" -> Sort@$Packages
            |>,
            "Directories" -> <|
                "$HomeDirectory" -> $HomeDirectory,
                "HomeDirectory[]" -> HomeDirectory[],
                "$UserBaseDirectory" -> $UserBaseDirectory,
                "$UserAddOnsDirectory" -> $UserAddOnsDirectory,
                "$UserBasePacletsDirectory" -> $UserBasePacletsDirectory,
                "$DefaultLocalBase" -> $DefaultLocalBase,
                "$LocalBase" -> $LocalBase,
                "$UserDocumentsDirectory" -> $UserDocumentsDirectory,
                "$WolframDocumentsDirectory" -> $WolframDocumentsDirectory,
                "$InitialDirectory" -> $InitialDirectory,
                "$PreferencesDirectory" -> $PreferencesDirectory,
                "$CacheBaseDirectory" -> $CacheBaseDirectory
            |>
        |>, InputForm] &
    ],


    (* HTTP-mode handlers *)

    "http-squared" -> APIFunction["x" -> "Number", #x^2 &],

    "http-form" :> FormFunction["x" -> "String"],
    "http-image" -> Delayed[RandomImage[], "PNG"],
    "http-image-form" :> FormFunction[
        {"image" -> "Image", "filter" -> ImageEffect[]}, 
        ImageEffect[#image, #filter] &,
        "PNG",
        AppearanceRules -> <|
            "Title" -> "Welcome to Wolfram Web Engine for AWS Lambda",
            "Description" -> TemplateApply[
                "This is a sample application running on a `` kernel.",
                $VersionNumber
            ]
        |>
    ],

    "http-dispatcher" -> URLDispatcher[{
        "/api" -> APIFunction["x" -> "String"],
        "/form" :> FormFunction["x" -> "String"],
        "/image" -> Delayed[RandomImage[], "PNG"],

        StringExpression[
            "/power/",
            base : Repeated[DigitCharacter, 3],
            "^",
            power : Repeated[DigitCharacter, 3]
        ] :> ExportForm[
            FromDigits[base] ^ FromDigits[power],
            "WL"
        ],

        "/" -> Delayed@ExportForm[
            StringJoin@{
                "Hello! I am a URLDispatcher. Try one of these links: ",
                "<a href=\"api\">/api</a>, ",
                "<a href=\"form\">/form</a>, ",
                "<a href=\"image\">/image</a>, ",
                "<a href=\"power/42^24\">/power/42^24</a>",
                "<br/><br/>",
                "Here is the current HTTPRequestData[]:<br/>",
                "<code>",
                ToString[HTTPRequestData[], InputForm],
                "</code><br/>",
                "And the $HTTPRequest:<br/>",
                "<code>",
                ToString[$HTTPRequest, InputForm],
                "</code>"
            },
            "HTML"
        ]
    }],

    "http-redirect" -> Delayed@HTTPRedirect["https://wolfram.com"],
    "http-error" -> Delayed@HTTPErrorResponse[500],

    "http-debugData" -> Delayed[
        <|
            "$AWSLambdaHandlerName" -> $AWSLambdaHandlerName,
            "$AWSLambdaHandlerMode" -> $AWSLambdaHandlerMode,
            "$AWSLambdaContextData" -> $AWSLambdaContextData,
            "$AWSLambdaRawRequestMetadata" -> $AWSLambdaRawRequestMetadata,

            "$HTTPRequest" -> $HTTPRequest,
            "HTTPRequestData[]" -> HTTPRequestData[],
            "$RequesterAddress" -> $RequesterAddress,
            "$UserAgentString" -> $UserAgentString
        |>,
        {"JSON", "ConversionFunction" -> (ToString[#, InputForm] &)}
    ]

|>